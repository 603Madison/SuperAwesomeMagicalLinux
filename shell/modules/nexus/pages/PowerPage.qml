pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Power & battery: the battery's state and health, the power mode (tuned-ppd), a charge limit
// where the laptop has one (UPower; Framework laptops do), and when the screen locks, turns off
// and the computer sleeps (the shell's idle timeouts).
PageBase {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false

    // UPower's own battery device (for the charge limit), e.g. /org/freedesktop/UPower/devices/battery_BAT1
    property string batteryPath
    property bool limitSupported
    property bool limitEnabled
    property int limitEnd: 80

    // The idle timeouts, by what they do.
    readonly property var timeouts: GlobalConfig.general.idle.timeouts
    readonly property list<MenuItem> minuteItems: [
        MenuItem {
            text: Tr.tr("1 minute")
            value: 60
        },
        MenuItem {
            text: Tr.tr("2 minutes")
            value: 120
        },
        MenuItem {
            text: Tr.tr("3 minutes")
            value: 180
        },
        MenuItem {
            text: Tr.tr("5 minutes")
            value: 300
        },
        MenuItem {
            text: Tr.tr("10 minutes")
            value: 600
        },
        MenuItem {
            text: Tr.tr("15 minutes")
            value: 900
        },
        MenuItem {
            text: Tr.tr("30 minutes")
            value: 1800
        },
        MenuItem {
            text: Tr.tr("1 hour")
            value: 3600
        },
        MenuItem {
            text: Tr.tr("Never")
            value: 0
        }
    ]

    function timeoutIndex(kind: string): int {
        for (let i = 0; i < timeouts.values.length; i++) {
            const action = timeouts.at(i).idleAction;
            const name = Array.isArray(action) ? action.join(" ") : String(action ?? "");
            if (kind === "lock" ? name === "lock" : kind === "screen" ? name.startsWith("dpms off") : /suspend|hibernate/i.test(name))
                return i;
        }
        return -1;
    }

    function timeoutValue(kind: string): int {
        const i = timeoutIndex(kind);
        if (i < 0)
            return 0;
        const t = timeouts.at(i);
        return t.enabled ? t.timeout : 0;
    }

    function setTimeout(kind: string, seconds: int): void {
        let i = timeoutIndex(kind);
        if (i < 0) {
            if (seconds === 0)
                return;
            timeouts.insert(kind === "lock" ? {
                timeout: seconds,
                idleAction: "lock"
            } : kind === "screen" ? {
                timeout: seconds,
                idleAction: "dpms off",
                returnAction: "dpms on"
            } : {
                timeout: seconds,
                idleAction: ["suspend"]
            });
            return;
        }
        const t = timeouts.at(i);
        t.enabled = seconds > 0;
        if (seconds > 0)
            t.timeout = seconds;
    }

    function duration(seconds: real): string {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600), m = Math.round((seconds % 3600) / 60);
        return h > 0 ? Tr.tr("%1 h %2 min").arg(h).arg(m) : Tr.tr("%1 min").arg(m);
    }

    function refreshLimit(): void {
        findBattery.running = true;
    }

    title: Tr.tr("Power & battery")

    Component.onCompleted: refreshLimit()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: findBattery

            command: ["upower", "-e"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.batteryPath = text.split("\n").find(p => p.includes("/battery_")) ?? "";
                    if (root.batteryPath)
                        readLimit.running = true;
                }
            }
        }

        Process {
            id: readLimit

            command: ["sh", "-c", `for p in ChargeThresholdSupported ChargeThresholdEnabled ChargeEndThreshold; do busctl get-property --system org.freedesktop.UPower '${root.batteryPath}' org.freedesktop.UPower.Device $p; done`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n");
                    root.limitSupported = lines[0] === "b true";
                    root.limitEnabled = lines[1] === "b true";
                    root.limitEnd = Number((lines[2] ?? "").split(" ")[1]) || 80;
                }
            }
        }

        Process {
            id: setLimit

            onExited: readLimit.running = true
        }

        // Battery
        ConnectedRect {
            Layout.fillWidth: true
            visible: root.hasBattery
            first: true
            last: true
            implicitHeight: batteryLayout.implicitHeight + Tokens.padding.extraLarge * 2

            RowLayout {
                id: batteryLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.large

                MaterialIcon {
                    text: root.battery?.state === UPowerDeviceState.Charging ? "battery_charging_full" : "battery_full"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.extraLarge
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: `${Math.round((root.battery?.percentage ?? 0) * 100)}%`
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.headline.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const b = root.battery;
                            if (!b)
                                return "";
                            if (b.state === UPowerDeviceState.FullyCharged)
                                return Tr.tr("Fully charged");
                            if (b.state === UPowerDeviceState.Charging)
                                return b.timeToFull > 0 ? Tr.tr("Charging, full in %1").arg(root.duration(b.timeToFull)) : Tr.tr("Charging");
                            if (b.state === UPowerDeviceState.PendingCharge)
                                return Tr.tr("Plugged in, not charging");
                            return b.timeToEmpty > 0 ? Tr.tr("On battery, %1 left").arg(root.duration(b.timeToEmpty)) : Tr.tr("On battery");
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: (root.battery?.healthPercentage ?? 0) > 0
                        text: Tr.tr("Battery health: %1% of what it held new").arg(Math.round(root.battery?.healthPercentage ?? 0))
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.medium
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Power mode
        SectionHeader {
            first: !root.hasBattery
            text: Tr.tr("Power mode")
        }

        SelectRow {
            first: true
            last: !root.limitSupported
            label: Tr.tr("Power mode")
            subtext: PowerProfiles.degradationReason !== PerformanceDegradationReason.None ? Tr.tr("Slowed down for now, to keep cool") : Tr.tr("Battery life or speed")
            menuItems: PowerProfiles.hasPerformanceProfile ? [saver, balanced, performance] : [saver, balanced]
            active: menuItems.find(i => i.value === PowerProfiles.profile) ?? balanced
            onSelected: item => PowerProfiles.profile = item.value

            MenuItem {
                id: saver

                text: Tr.tr("Battery saver")
                value: PowerProfile.PowerSaver
            }
            MenuItem {
                id: balanced

                text: Tr.tr("Balanced")
                value: PowerProfile.Balanced
            }
            MenuItem {
                id: performance

                text: Tr.tr("Performance")
                value: PowerProfile.Performance
            }
        }

        ToggleRow {
            visible: root.limitSupported
            last: true
            text: Tr.tr("Limit charging to %1%").arg(root.limitEnd)
            subtext: Tr.tr("A battery kept below full lasts more years; best when mostly plugged in")
            checked: root.limitEnabled
            onToggled: setLimit.exec(["busctl", "call", "--system", "org.freedesktop.UPower", root.batteryPath, "org.freedesktop.UPower.Device", "EnableChargeThreshold", "b", checked ? "true" : "false"])
        }

        // Screen and sleep
        SectionHeader {
            text: Tr.tr("Screen and sleep")
        }

        SelectRow {
            first: true
            label: Tr.tr("Lock the screen after")
            subtext: Tr.tr("Of not being used")
            menuItems: root.minuteItems
            active: menuItems.find(i => i.value === root.timeoutValue("lock")) ?? null
            fallbackText: root.duration(root.timeoutValue("lock"))
            onSelected: item => root.setTimeout("lock", item.value)
        }

        SelectRow {
            label: Tr.tr("Turn the screen off after")
            menuItems: root.minuteItems
            active: menuItems.find(i => i.value === root.timeoutValue("screen")) ?? null
            fallbackText: root.duration(root.timeoutValue("screen"))
            onSelected: item => root.setTimeout("screen", item.value)
        }

        SelectRow {
            label: Tr.tr("Sleep after")
            menuItems: root.minuteItems
            active: menuItems.find(i => i.value === root.timeoutValue("sleep")) ?? null
            fallbackText: root.duration(root.timeoutValue("sleep"))
            onSelected: item => root.setTimeout("sleep", item.value)
        }

        ToggleRow {
            text: Tr.tr("Stay awake while music or video plays")
            checked: GlobalConfig.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        ToggleRow {
            visible: root.hasBattery
            text: Tr.tr("Stay awake while plugged in")
            checked: GlobalConfig.general.idle.inhibitWhenCharging
            onToggled: GlobalConfig.general.idle.inhibitWhenCharging = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Lock the screen when going to sleep")
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }
    }
}
