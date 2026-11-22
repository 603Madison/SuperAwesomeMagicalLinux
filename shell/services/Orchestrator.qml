pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

// SuperAwesomeMagicalOrchestrator: one sign-in for the family's apps on this computer, and this
// computer among the person's devices (notifications, clipboard, links, ringing, carrying on).
//
// Its agent is a user service on the session bus (app.superawesomemagical.Orchestrator) that the
// bus starts when something asks for it. Quickshell can't call D-Bus methods, so this asks through
// the agent's own command (`sam-orchestrator … --json`), always with the arguments as a list, never
// a shell line: device names and addresses come from other devices and the server.
//
// `gdbus monitor` says whether the agent is running (from the bus's NameOwnerChanged, which doesn't
// start it) and passes on its Changed and ActivitiesChanged signals. The agent is only asked
// anything while it's running already (start-shell wakes it at sign-in for accounts that are signed in) or while
// something on screen wants it (`refs`, held by the Settings pages), so it isn't started for people
// who don't use it.
Singleton {
    id: root

    readonly property string program: "sam-orchestrator"
    readonly property string busName: "app.superawesomemagical.Orchestrator"

    // Whether the agent is in this image at all ("" until looked for).
    property string installed: ""
    readonly property bool available: installed === "yes"
    // The agent's connection on the session bus (":1.42"), or "" while it isn't running.
    property string agentOwner
    readonly property bool agentRunning: agentOwner !== ""
    // How many things on screen want it kept up to date (and started, if it isn't running).
    property int refs
    readonly property bool active: available && (agentRunning || refs > 0)
    // True once Status has been read.
    property bool loaded
    // True when the agent couldn't be asked (it wouldn't start, or isn't answering).
    property bool unreachable

    // As the agent gives them (docs/PROTOCOL.md in SAM-DeviceOrchestrator).
    property var status: ({})
    property var devices: []
    property var apps: []
    property var activities: []
    property var settings: ({})

    readonly property bool signedIn: status.signedIn === true
    readonly property bool signingIn: status.signingIn === true
    readonly property bool connected: status.connected === true
    readonly property string pairingCode: status.pairingCode ?? ""
    readonly property string signInUrl: status.signInUrl ?? ""
    readonly property string server: status.server ?? ""
    readonly property string username: status.username ?? ""
    readonly property string displayName: status.displayName || username
    readonly property string deviceName: status.device?.name ?? ""
    // Why the last sign-in didn't work (the agent's words), or the last thing asked for here.
    readonly property string signInError: signingIn ? "" : (status.error ?? "")
    property string actionError

    readonly property var otherDevices: devices.filter(d => !d.current)
    // Devices rung from here, by id, until when (a ring lasts a minute; the agent doesn't say).
    property var ringing: ({})

    function watch(): void {
        if (!available)
            return;
        ownerWatch.running = true;
        ownerCheck.running = true;
    }

    function refresh(): void {
        if (active)
            debounce.restart();
    }

    function signIn(server: string): void {
        const address = server.trim();
        if (!address || !available)
            return;
        actionError = "";
        // Status first, so the agent is running and does the signing in itself: then its Status
        // has the pairing code to show. ("--": the address is never read as an option.)
        act(["status", "--json"], () => act(["sign-in", "--", address]));
        soon.restart();
    }

    function signOut(): void {
        act(["sign-out"]);
    }

    function ring(id: string, on: bool): void {
        const next = Object.assign({}, ringing);
        if (on)
            next[id] = Date.now() + 60000;
        else
            delete next[id];
        ringing = next;
        act(on ? ["ring", "--", id] : ["ring", "--stop", "--", id]);
    }

    function isRinging(id: string): bool {
        return (ringing[id] ?? 0) > ringClock.now;
    }

    // To one device, or to all the others when no id is given.
    function sendClipboard(id: string): void {
        act(id ? ["send-clipboard", "--", id] : ["send-clipboard"]);
    }

    function setSetting(key: string, on: bool): void {
        // Show it at once; the agent's answer follows.
        const next = Object.assign({}, settings);
        next[key] = on;
        settings = next;
        act(["settings", key, on ? "true" : "false"]);
    }

    // The same rule the agent keeps for links from other devices: the web, or one of the family's
    // own apps; nothing with spaces or control characters, nothing else.
    function mayOpen(url: string): bool {
        return /^(https?:\/\/[^\s\/@]+(\/\S*)?|(samvideo|sammusic|samemail|samaps|samhealth):\S+)$/i.test(url) && !/[\x00-\x20\x7f]/.test(url);
    }

    function open(url: string): void {
        if (mayOpen(url))
            Quickshell.execDetached(["xdg-open", url]);
    }

    function act(args: list<string>, then: var): void {
        actionComp.createObject(root, {
            command: [program, ...args],
            then: then ?? null
        });
    }

    function readJson(text: string, fallback: var): var {
        try {
            return JSON.parse(text);
        } catch (e) {
            return fallback;
        }
    }

    function clear(): void {
        devices = [];
        apps = [];
        activities = [];
    }

    onActiveChanged: {
        if (active)
            debounce.restart();
    }
    onRefsChanged: {
        if (refs > 0)
            debounce.restart();
    }
    onAvailableChanged: watch()
    onAgentOwnerChanged: {
        if (!agentRunning) {
            loaded = false;
            status = {};
        }
        refresh();
    }
    onSignedInChanged: {
        if (!signedIn)
            clear();
    }

    // Is the agent in this image? (It's left out of builds that couldn't see a release of it.)
    Process {
        running: true
        command: ["sh", "-c", "command -v sam-orchestrator"]
        onExited: code => root.installed = code === 0 ? "yes" : "no" // qmllint disable signal-handler-parameters
    }

    // Whether the agent is running: asked once, then the bus's own word on who owns its name.
    // (Not `gdbus monitor --dest <the agent's name>`: that starts the agent.)
    Process {
        id: ownerCheck

        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus", "--method", "org.freedesktop.DBus.GetNameOwner", root.busName]
        stdout: StdioCollector {
            onStreamFinished: {
                const owner = text.match(/'(:[^']+)'/);
                if (owner)
                    root.agentOwner = owner[1];
            }
        }
    }

    Process {
        id: ownerWatch

        command: ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes(`NameOwnerChanged ('${root.busName}',`))
                    return;
                const owners = line.match(/, '([^']*)', '([^']*)'\)\s*$/);
                if (owners)
                    root.agentOwner = owners[2];
            }
        }
        onExited: rewatch.start()
    }

    // The agent's signals (Changed, ActivitiesChanged), from its connection while it has one:
    // watching a connection by its own name can't start anything.
    Process {
        id: signalWatch

        running: root.agentOwner !== ""
        command: ["gdbus", "monitor", "--session", "--dest", root.agentOwner]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("Changed ()"))
                    root.refresh();
            }
        }
    }

    Timer {
        id: rewatch

        interval: 5000
        onTriggered: root.watch()
    }

    // Several signals in a row are one look.
    Timer {
        id: debounce

        interval: 150
        onTriggered: statusProc.running = true
    }

    // Once more shortly after asking for something whose answer comes by itself (a sign-in's code).
    Timer {
        id: soon

        interval: 1200
        onTriggered: root.refresh()
    }

    // In case a signal is missed: now and then, and more often while a sign-in waits.
    Timer {
        running: root.active
        repeat: true
        interval: root.signingIn ? 3000 : 60000
        onTriggered: root.refresh()
    }

    Timer {
        id: ringClock

        property real now: Date.now()

        running: Object.keys(root.ringing).length > 0
        repeat: true
        interval: 1000
        onTriggered: {
            now = Date.now();
            if (Object.values(root.ringing).every(until => until <= now))
                root.ringing = {};
        }
    }

    Process {
        id: statusProc

        command: [root.program, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const status = root.readJson(text, null);
                if (!status)
                    return;
                root.status = status;
                root.loaded = true;
                root.unreachable = false;
                if (status.signedIn === true) {
                    devicesProc.running = true;
                    appsProc.running = true;
                    activitiesProc.running = true;
                    settingsProc.running = true;
                }
            }
        }
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0) {
                root.unreachable = true;
                root.status = {};
            }
        }
    }

    Process {
        id: devicesProc

        command: [root.program, "devices", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.readJson(text, null);
                if (Array.isArray(list))
                    // This computer first, then the ones that are here, then by name.
                    root.devices = list.sort((a, b) => (b.current === true) - (a.current === true) || (b.online === true) - (a.online === true) || String(a.name).localeCompare(String(b.name)));
            }
        }
    }

    Process {
        id: appsProc

        command: [root.program, "apps", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.readJson(text, null);
                if (Array.isArray(list))
                    root.apps = list;
            }
        }
    }

    Process {
        id: activitiesProc

        command: [root.program, "activities", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.readJson(text, null);
                if (Array.isArray(list))
                    root.activities = list;
            }
        }
    }

    Process {
        id: settingsProc

        command: [root.program, "settings", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const settings = root.readJson(text, null);
                if (settings && typeof settings === "object")
                    root.settings = settings;
            }
        }
    }

    // One thing asked of the agent. The command says why in words when it didn't work.
    Component {
        id: actionComp

        Process {
            id: action

            property var then
            property int code: -1
            property bool said

            function finish(): void {
                if (code < 0 || !said)
                    return;
                if (code !== 0)
                    root.actionError = words.text.trim().split("\n").pop() || Tr.tr("That didn’t work.");
                else if (then)
                    then();
                root.refresh();
                destroy();
            }

            running: true
            stdout: StdioCollector {}
            stderr: StdioCollector {
                id: words

                onStreamFinished: {
                    action.said = true;
                    action.finish();
                }
            }
            onExited: exitCode => { // qmllint disable signal-handler-parameters
                code = exitCode;
                finish();
            }
        }
    }
}
