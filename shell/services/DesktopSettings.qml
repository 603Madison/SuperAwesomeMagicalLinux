pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services
import qs.utils

// The settings that belong to the desktop rather than the shell: Hyprland's (displays, mouse,
// touchpad, keyboard), night light, light and dark by the time of day, and the time zone.
//
// They're kept in ~/.config/caelestia/desktop.json. Hyprland's part is also written out as
// ~/.config/caelestia/hypr-settings.lua, which hyprland.lua loads at start (before hypr-user.lua, so
// a person's own config still wins), and applied to the running Hyprland at once.
Singleton {
    id: root

    // Hyprland options by Hyprland's name for them, e.g. "input:touchpad:natural_scroll": true.
    readonly property var options: adapter.options
    // Display settings by display (see monitorKey()): { mode, position, scale, transform, vrr,
    // mirror, disabled }, as hl.monitor() takes them.
    readonly property var monitors: adapter.monitors
    readonly property alias nightLight: adapter.nightLight
    readonly property alias theme: adapter.theme
    readonly property alias time: adapter.time
    readonly property alias accessibility: adapter.accessibility

    // The displays as Hyprland has them now (`hyprctl monitors all`, so turned-off ones too).
    property var outputs: []

    // After a change to the displays, what to go back to unless it's kept within revertSeconds.
    property var revertTo: null
    property int revertSecondsLeft
    readonly property int revertSeconds: 15

    // The clock (from timedated and chrony).
    property string timezone
    property bool ntp
    property bool ntpSynced
    property string timeServer

    // Sunrise and sunset ("HH:MM") from the weather, or a sensible guess until it has them.
    readonly property string sunrise: Weather.cc?.sunrise?.split(" ")[1] ?? "07:00"
    readonly property string sunset: Weather.cc?.sunset?.split(" ")[1] ?? "19:00"
    readonly property int minuteOfDay: clock.hours * 60 + clock.minutes

    readonly property bool nightLightActive: nightLight.enabled && (nightLight.schedule === "always" || (nightLight.schedule === "sun" ? inRange(sunset, sunrise) : inRange(nightLight.from, nightLight.to)))
    // "light" or "dark" when the theme follows the time of day, else "".
    readonly property string scheduledMode: theme.auto === "off" ? "" : (theme.auto === "sun" ? inRange(sunset, sunrise) : inRange(theme.darkFrom, theme.lightFrom)) ? "dark" : "light"

    //// Hyprland options ////////////////////////////////////////////////////////////////////////

    // What's chosen, else what Hyprland has now, else the fallback. Keys are the Lua config's names
    // ("input:touchpad:tap_to_click"); Hyprland reports some with hyphens ("tap-to-click").
    function option(key: string, fallback: var): var {
        if (key in options)
            return options[key];
        const parts = key.split(":");
        const hyphened = [...parts.slice(0, -1), parts[parts.length - 1].replace(/_/g, "-")].join(":");
        const current = Hypr.options[key] ?? Hypr.options[hyphened];
        return current === undefined || current === null ? fallback : current;
    }

    function setOption(key: string, value: var): void {
        const next = Object.assign({}, options);
        next[key] = value;
        adapter.options = next;
        // (Not HyprExtras.applyOptions, which writes values as they are rather than as Lua.)
        Hypr.extras.message(`eval hl.config(${luaTable(nest({
            [key]: value
        }))})`);
        luaWrite.restart();
    }

    // { "a:b:c": v }  ->  { a: { b: { c: v } } }
    function nest(flat: var): var {
        const nested = {};
        for (const [key, value] of Object.entries(flat)) {
            const parts = key.split(":");
            let node = nested;
            for (const p of parts.slice(0, -1))
                node = node[p] = node[p] ?? {};
            node[parts[parts.length - 1]] = value;
        }
        return nested;
    }

    //// Accessibility ///////////////////////////////////////////////////////////////////////////

    function setCursorSize(size: int): void {
        accessibility.cursorSize = size;
        applyCursorSize();
    }

    function applyCursorSize(): void {
        const size = String(accessibility.cursorSize);
        Quickshell.execDetached(["hyprctl", "setcursor", "Adwaita", size]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", size]);
    }

    // Hyprland's window animations off, and the shell's own quicker.
    function setReduceMotion(on: bool): void {
        accessibility.reduceMotion = on;
        setOption("animations:enabled", !on);
        GlobalConfig.appearance.anim.durations.scale = on ? 0.3 : 1;
    }

    //// Displays ////////////////////////////////////////////////////////////////////////////////

    // Settings follow a display by its make, model and serial (Hyprland's "desc:"), so they stay
    // with it whichever port it's plugged into.
    function monitorKey(output: var): string {
        return output.description ? `desc:${output.description}` : output.name;
    }

    // A display's settings as they are now, as a rule. (One that's off has no size to go by, so it
    // comes back as it likes best.)
    function currentRule(output: var): var {
        if (output.disabled || !output.width)
            return {
                mode: "preferred",
                position: "auto",
                scale: "auto",
                transform: 0
            };
        return {
            mode: `${output.width}x${output.height}@${Number(output.refreshRate).toFixed(3)}`,
            position: `${output.x}x${output.y}`,
            scale: String(Math.round(output.scale * 1000000) / 1000000),
            transform: output.transform
        };
    }

    function ruleFor(output: var): var {
        return monitors[monitorKey(output)] ?? currentRule(output);
    }

    // Changes some of a display's settings, keeping what it had to go back to unless kept.
    function setMonitor(output: var, changes: var): void {
        const key = monitorKey(output);
        const before = Object.assign({}, ruleFor(output));
        const after = Object.assign({}, before, changes);

        const revert = Object.assign({}, revertTo ?? {});
        if (!(key in revert))
            revert[key] = before;
        revertTo = revert;
        revertSecondsLeft = revertSeconds;
        revertTimer.restart();

        storeMonitor(key, after);
    }

    function keepDisplays(): void {
        revertTimer.stop();
        revertTo = null;
    }

    function revertDisplays(): void {
        revertTimer.stop();
        const revert = revertTo ?? {};
        revertTo = null;
        for (const [key, rule] of Object.entries(revert))
            storeMonitor(key, rule);
    }

    function storeMonitor(key: string, rule: var): void {
        const next = Object.assign({}, monitors);
        next[key] = rule;
        adapter.monitors = next;
        // Clear what isn't set, as hl.monitor() keeps the fields of an earlier rule.
        Hypr.extras.message(`eval hl.monitor(${monitorLua(key, Object.assign({
            mirror: "",
            disabled: false
        }, rule))})`);
        writeLua();
        refreshOutputs();
    }

    function refreshOutputs(): void {
        outputsProc.running = true;
    }

    //// The clock ///////////////////////////////////////////////////////////////////////////////

    function refreshTime(): void {
        timedateProc.running = true;
        trackingProc.running = true;
    }

    // ask: whether polkit may ask for a password (not for the automatic time zone).
    function setTimezone(tz: string, ask: bool): void {
        const cmd = ["timedatectl"];
        if (!ask)
            cmd.push("--no-ask-password");
        setTimeProc.exec([...cmd, "set-timezone", tz]);
    }

    function setNtp(on: bool): void {
        setTimeProc.exec(["timedatectl", "set-ntp", on ? "true" : "false"]);
    }

    // Asks for the time again now: switching network time off and on restarts chrony, which then
    // puts the clock right at once (makestep, see build.sh).
    function syncNow(): void {
        setTimeProc.exec(["sh", "-c", "timedatectl set-ntp false && timedatectl set-ntp true"]);
    }

    function checkTimezone(): void {
        if (!time.autoTimezone)
            return;
        Requests.get("http://ip-api.com/json?fields=status,timezone", text => {
            let tz = "";
            try {
                const r = JSON.parse(text);
                if (r.status === "success")
                    tz = r.timezone ?? "";
            } catch (e) {}
            if (!/^[A-Za-z]+(\/[A-Za-z0-9_+-]+)*$/.test(tz)) {
                tzRetry.restart();
                return;
            }
            if (tz !== root.timezone && root.time.autoTimezone)
                root.setTimezone(tz, false);
        }, () => tzRetry.restart());
    }

    //// Schedules ///////////////////////////////////////////////////////////////////////////////

    function minutesOf(hhmm: string): int {
        const [h, m] = (hhmm || "0:0").split(":").map(Number);
        return (h || 0) * 60 + (m || 0);
    }

    // Whether now is between from and to ("HH:MM"), across midnight if to is earlier.
    function inRange(from: string, to: string): bool {
        const now = minuteOfDay, start = minutesOf(from), end = minutesOf(to);
        return start <= end ? now >= start && now < end : now >= start || now < end;
    }

    function applyScheduledMode(): void {
        if (scheduledMode && (scheduledMode === "light") !== Colours.currentLight)
            Quickshell.execDetached(["caelestia", "scheme", "set", "-m", scheduledMode]);
    }

    // Light or dark changes when the time of day says so, so switching by hand in between holds
    // until the next sunrise or sunset.
    onScheduledModeChanged: applyScheduledMode()

    onNightLightActiveChanged: {
        if (nightLightActive)
            sunsetProc.running = true;
        else
            sunsetProc.signal(15);
    }

    //// Writing it out //////////////////////////////////////////////////////////////////////////

    // A value as Lua source.
    function lua(value: var): string {
        if (typeof value === "boolean" || typeof value === "number")
            return String(value);
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n")}"`;
    }

    function luaTable(obj: var): string {
        const parts = Object.entries(obj).map(([k, v]) => `${/^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : `[${lua(k)}]`} = ${typeof v === "object" && v !== null ? luaTable(v) : lua(v)}`);
        return `{ ${parts.join(", ")} }`;
    }

    function monitorLua(key: string, rule: var): string {
        const fields = {
            output: key
        };
        for (const f of ["mode", "position", "scale", "transform", "vrr", "mirror", "disabled"])
            if (f in rule && rule[f] !== undefined && rule[f] !== null)
                fields[f] = rule[f];
        return luaTable(fields);
    }

    function writeLua(): void {
        const nested = nest(options);

        const lines = ["-- Written by Settings: your choices for displays, the mouse, touchpad and keyboard.", "-- Settings rewrites this file, so put changes of your own in hypr-user.lua instead.", ""];
        if (Object.keys(nested).length > 0)
            lines.push(`hl.config(${luaTable(nested)})`);
        for (const [key, rule] of Object.entries(monitors))
            if (!rule.mirror || rule.mirror === "")
                lines.push(`hl.monitor(${monitorLua(key, rule)})`);
        // Mirrors after the displays they copy.
        for (const [key, rule] of Object.entries(monitors))
            if (rule.mirror)
                lines.push(`hl.monitor(${monitorLua(key, rule)})`);
        luaFile.setText(lines.join("\n") + "\n");
    }

    // Sliders change options many times a second; write the file once they settle.
    Timer {
        id: luaWrite

        interval: 500
        onTriggered: root.writeLua()
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    FileView {
        id: store

        path: `${Paths.config}/desktop.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property var options: ({})
            property var monitors: ({})

            property JsonObject nightLight: JsonObject {
                property bool enabled: false
                // "sun" (sunset to sunrise), "custom" (from-to) or "always"
                property string schedule: "sun"
                property string from: "20:00"
                property string to: "07:00"
                property int temperature: 4000
            }

            property JsonObject theme: JsonObject {
                // "off", "sun" (dark from sunset to sunrise) or "custom"
                property string auto: "off"
                property string lightFrom: "07:00"
                property string darkFrom: "19:00"
            }

            property JsonObject time: JsonObject {
                property bool autoTimezone: true
            }

            property JsonObject accessibility: JsonObject {
                property int cursorSize: 24
                property bool reduceMotion: false
            }
        }
    }

    FileView {
        id: luaFile

        path: `${Paths.config}/hypr-settings.lua`
    }

    Process {
        id: outputsProc

        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.outputs = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Timer {
        id: revertTimer

        interval: 1000
        repeat: true
        onTriggered: {
            if (--root.revertSecondsLeft <= 0)
                root.revertDisplays();
        }
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (["monitoradded", "monitorremoved", "configreloaded"].includes(event.name))
                root.refreshOutputs();
        }

        target: Hyprland
    }

    // Night light: hyprsunset tints the screen while it runs.
    Process {
        id: sunsetProc

        command: ["hyprsunset", "-t", String(root.nightLight.temperature)]
    }

    Connections {
        function onTemperatureChanged(): void {
            if (sunsetProc.running)
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.nightLight.temperature)]);
        }

        target: root.nightLight
    }

    Process {
        id: timedateProc

        command: ["timedatectl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const props = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        props[line.slice(0, i)] = line.slice(i + 1);
                }
                root.timezone = props.Timezone ?? "";
                root.ntp = props.NTP === "yes";
                root.ntpSynced = props.NTPSynchronized === "yes";
            }
        }
    }

    Process {
        id: trackingProc

        command: ["chronyc", "-c", "tracking"]
        stdout: StdioCollector {
            // CSV: reference ID, its name or address, stratum, ...
            onStreamFinished: root.timeServer = text.split(",")[1] ?? ""
        }
    }

    Process {
        id: setTimeProc

        onExited: root.refreshTime()
    }

    Timer {
        id: tzRetry

        interval: 120000
        onTriggered: root.checkTimezone()
    }

    Timer {
        running: root.time.autoTimezone
        repeat: true
        interval: 3 * 60 * 60 * 1000
        onTriggered: root.checkTimezone()
    }

    Connections {
        function onAutoTimezoneChanged(): void {
            root.checkTimezone();
        }

        target: root.time
    }

    // `caelestia shell desktop ...` (or qs ipc call desktop ...), e.g. for a key to toggle night light.
    IpcHandler {
        function toggleNightLight(): void {
            root.nightLight.enabled = !root.nightLight.enabled;
        }

        function nightLight(on: bool): void {
            root.nightLight.enabled = on;
        }

        // A Hyprland option as Settings would set it; the value is JSON (true, 0.5, "us,de").
        function setOption(key: string, value: string): void {
            root.setOption(key, JSON.parse(value));
        }

        function getOptions(): string {
            return JSON.stringify(root.options);
        }

        target: "desktop"
    }

    // At start: the clock, the displays, and anything scheduled (once the colours are read).
    Timer {
        running: true
        interval: 3000
        onTriggered: {
            root.refreshTime();
            root.refreshOutputs();
            root.applyScheduledMode();
            // (Hyprland sets the pointer from its own config when it starts, before this.)
            if (root.accessibility.cursorSize !== 24)
                root.applyCursorSize();
            if (root.nightLightActive)
                sunsetProc.running = true;
            root.checkTimezone();
        }
    }
}
