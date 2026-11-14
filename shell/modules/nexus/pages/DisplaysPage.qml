pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Displays: resolution, refresh rate, scale, rotation and arrangement for each one (applied at
// once, and put back after a few seconds unless kept, in case the screen can't show it), their
// brightness, and night light. DesktopSettings keeps them and hands them to Hyprland.
PageBase {
    id: root

    readonly property var outputs: DesktopSettings.outputs
    readonly property var enabledOutputs: outputs.filter(o => !o.disabled)

    // "2256x1504@60.00Hz" -> { res: "2256x1504", w, h, rate: 60, mode: "2256x1504@60.00" }
    function parseMode(m: string): var {
        const match = m.match(/^(\d+)x(\d+)@([\d.]+)/);
        if (!match)
            return null;
        return {
            res: `${match[1]}x${match[2]}`,
            w: Number(match[1]),
            h: Number(match[2]),
            rate: Number(match[3]),
            mode: `${match[1]}x${match[2]}@${match[3]}`
        };
    }

    function modesOf(output: var): var {
        return (output.availableModes ?? []).map(parseMode).filter(m => m);
    }

    // Resolutions, biggest first.
    function resolutionsOf(output: var): var {
        const seen = [];
        for (const m of modesOf(output).sort((a, b) => b.w * b.h - a.w * a.h))
            if (!seen.some(s => s.res === m.res))
                seen.push(m);
        return seen;
    }

    function ratesOf(output: var): var {
        return modesOf(output).filter(m => m.res === `${output.width}x${output.height}`).sort((a, b) => b.rate - a.rate);
    }

    // The scales Hyprland can show crisply at this resolution (whole logical pixels, in 120ths, as
    // fractional scaling has them), picked out near the usual steps.
    function scalesOf(output: var): var {
        const w = output.width, h = output.height;
        const valid = [];
        for (let k = 60; k <= 480; k++)
            if ((w * 120) % k === 0 && (h * 120) % k === 0)
                valid.push(k / 120);
        const picked = [];
        for (const want of [1, 1.25, 1.333, 1.5, 1.6, 1.75, 2, 2.25, 2.5, 3]) {
            const best = valid.reduce((a, b) => Math.abs(b - want) < Math.abs(a - want) ? b : a, valid[0]);
            if (best !== undefined && Math.abs(best - want) <= 0.12 && !picked.includes(best))
                picked.push(best);
        }
        const current = Math.round(output.scale * 120) / 120;
        if (!picked.some(s => Math.abs(s - current) < 0.001))
            picked.push(current);
        return picked.sort((a, b) => a - b);
    }

    function displayName(output: var): string {
        if (output.name.startsWith("eDP") || output.name.startsWith("LVDS") || output.name.startsWith("DSI"))
            return Tr.tr("Built-in display");
        const name = `${output.make ?? ""} ${output.model ?? ""}`.trim();
        return name || output.name;
    }

    function isValidTime(t: string): bool {
        return /^([01]?\d|2[0-3]):[0-5]\d$/.test(t);
    }

    title: Tr.tr("Displays")

    Component.onCompleted: DesktopSettings.refreshOutputs()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Keep the new settings, or they go back by themselves
        ConnectedRect {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.large
            visible: DesktopSettings.revertTo !== null
            first: true
            last: true
            color: Colours.palette.m3primaryContainer
            implicitHeight: keepLayout.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: keepLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "desktop_windows"
                    color: Colours.palette.m3onPrimaryContainer
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Keep these display settings?")
                        color: Colours.palette.m3onPrimaryContainer
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Going back to the old ones in %1 s").arg(DesktopSettings.revertSecondsLeft)
                        color: Colours.palette.m3onPrimaryContainer
                        font: Tokens.font.label.medium
                        elide: Text.ElideRight
                    }
                }

                TextButton {
                    type: TextButton.Text
                    isRound: true
                    text: Tr.tr("Go back")
                    onClicked: DesktopSettings.revertDisplays()
                }

                TextButton {
                    type: TextButton.Filled
                    isRound: true
                    text: Tr.tr("Keep")
                    onClicked: DesktopSettings.keepDisplays()
                }
            }
        }

        Repeater {
            model: root.outputs

            ColumnLayout {
                id: display

                required property var modelData
                required property int index
                readonly property var rule: DesktopSettings.ruleFor(modelData)
                readonly property bool canTurnOff: !modelData.disabled && root.enabledOutputs.length > 1
                readonly property bool showToggle: modelData.disabled || root.enabledOutputs.length > 1
                readonly property var others: root.enabledOutputs.filter(o => o.name !== modelData.name)
                // (Not every display can be dimmed from here.)
                readonly property var brightness: {
                    const b = Brightness.monitors.find(m => m.modelData.name === modelData.name);
                    return b && !isNaN(b.brightness) ? b : null;
                }

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: display.index === 0
                    text: root.displayName(display.modelData)
                }

                ToggleRow {
                    visible: display.showToggle
                    first: true
                    last: display.modelData.disabled
                    disabled: !display.modelData.disabled && !display.canTurnOff
                    text: Tr.tr("Use this display")
                    subtext: display.modelData.disabled ? Tr.tr("Turned off") : display.canTurnOff ? Tr.tr("Turn it off to use only the others") : Tr.tr("The only display in use")
                    checked: !display.modelData.disabled
                    onToggled: DesktopSettings.setMonitor(display.modelData, {
                        disabled: !checked
                    })
                }

                SliderRow {
                    visible: !display.modelData.disabled && display.brightness !== null
                    first: !display.showToggle
                    icon: "brightness_6"
                    label: Tr.tr("Brightness")
                    valueLabel: `${Math.round((display.brightness?.brightness ?? 0) * 100)}%`
                    value: display.brightness?.brightness ?? 0
                    onMoved: v => display.brightness?.setBrightness(Math.max(0.01, v))
                }

                SelectRow {
                    visible: !display.modelData.disabled
                    first: !display.showToggle && display.brightness === null
                    label: Tr.tr("Resolution")
                    subtext: Tr.tr("The first is the display's own")
                    fallbackText: `${display.modelData.width} × ${display.modelData.height}`
                    menuItems: resolutionItems.instances
                    active: menuItems.find(i => i.value === `${display.modelData.width}x${display.modelData.height}`) ?? null
                    onSelected: item => {
                        // The same refresh rate if it has it, else its fastest.
                        const modes = root.modesOf(display.modelData).filter(m => m.res === item.value).sort((a, b) => b.rate - a.rate);
                        const same = modes.find(m => Math.abs(m.rate - display.modelData.refreshRate) < 0.5);
                        DesktopSettings.setMonitor(display.modelData, {
                            mode: (same ?? modes[0]).mode
                        });
                    }

                    Variants {
                        id: resolutionItems

                        // (Variants keys its items by value, so plain strings.)
                        model: root.resolutionsOf(display.modelData).map(m => m.res)

                        MenuItem {
                            required property string modelData

                            text: modelData.replace("x", " × ") + (modelData === root.resolutionsOf(display.modelData)[0]?.res ? ` (${Tr.tr("recommended")})` : "")
                            value: modelData
                        }
                    }
                }

                SelectRow {
                    visible: !display.modelData.disabled && rateItems.instances.length > 1
                    label: Tr.tr("Refresh rate")
                    subtext: Tr.tr("Faster is smoother; slower saves battery")
                    fallbackText: `${Math.round(display.modelData.refreshRate)} Hz`
                    menuItems: rateItems.instances
                    active: menuItems.find(i => Math.abs(root.parseMode(i.value).rate - display.modelData.refreshRate) < 0.05) ?? null
                    onSelected: item => DesktopSettings.setMonitor(display.modelData, {
                        mode: item.value
                    })

                    Variants {
                        id: rateItems

                        model: root.ratesOf(display.modelData).map(m => m.mode)

                        MenuItem {
                            required property string modelData

                            text: `${Math.round(root.parseMode(modelData).rate * 100) / 100} Hz`
                            value: modelData
                        }
                    }
                }

                SelectRow {
                    visible: !display.modelData.disabled
                    label: Tr.tr("Scale")
                    subtext: Tr.tr("How big everything looks")
                    fallbackText: `${Math.round(display.modelData.scale * 100)}%`
                    menuItems: scaleItems.instances
                    active: menuItems.find(i => Math.abs(i.value - display.modelData.scale) < 0.005) ?? null
                    onSelected: item => DesktopSettings.setMonitor(display.modelData, {
                        scale: String(Math.round(item.value * 1000000) / 1000000)
                    })

                    Variants {
                        id: scaleItems

                        model: root.scalesOf(display.modelData)

                        MenuItem {
                            required property real modelData

                            text: `${Math.round(modelData * 100)}%`
                            value: modelData
                        }
                    }
                }

                SelectRow {
                    visible: !display.modelData.disabled
                    last: display.others.length === 0
                    label: Tr.tr("Orientation")
                    subtext: Tr.tr("Turn the picture to match the screen")
                    menuItems: [landscape, rotated90, rotated180, rotated270]
                    active: menuItems.find(i => i.value === display.modelData.transform) ?? landscape
                    onSelected: item => DesktopSettings.setMonitor(display.modelData, {
                        transform: item.value
                    })

                    MenuItem {
                        id: landscape

                        text: Tr.tr("Normal")
                        value: 0
                    }
                    MenuItem {
                        id: rotated90

                        text: Tr.tr("Turned 90°")
                        value: 1
                    }
                    MenuItem {
                        id: rotated180

                        text: Tr.tr("Upside down")
                        value: 2
                    }
                    MenuItem {
                        id: rotated270

                        text: Tr.tr("Turned 270°")
                        value: 3
                    }
                }

                SelectRow {
                    visible: !display.modelData.disabled && display.others.length > 0
                    last: true
                    label: Tr.tr("Position")
                    subtext: Tr.tr("Where it sits beside the other displays, or show the same as one")
                    fallbackText: Tr.tr("As arranged")
                    menuItems: [...positionItems, ...mirrorItems.instances]
                    active: {
                        const r = display.rule;
                        if (r.mirror)
                            return mirrorItems.instances.find(i => i.value.mirror === r.mirror) ?? null;
                        return positionItems.find(i => i.value.position === r.position) ?? null;
                    }
                    onSelected: item => DesktopSettings.setMonitor(display.modelData, item.value)

                    readonly property list<MenuItem> positionItems: [
                        MenuItem {
                            text: Tr.tr("Right of the others")
                            value: ({
                                    position: "auto-right",
                                    mirror: ""
                                })
                        },
                        MenuItem {
                            text: Tr.tr("Left of the others")
                            value: ({
                                    position: "auto-left",
                                    mirror: ""
                                })
                        },
                        MenuItem {
                            text: Tr.tr("Above the others")
                            value: ({
                                    position: "auto-up",
                                    mirror: ""
                                })
                        },
                        MenuItem {
                            text: Tr.tr("Below the others")
                            value: ({
                                    position: "auto-down",
                                    mirror: ""
                                })
                        }
                    ]

                    Variants {
                        id: mirrorItems

                        model: display.others.map(o => o.name)

                        MenuItem {
                            required property string modelData

                            text: Tr.tr("Same as %1").arg(root.displayName(root.outputs.find(o => o.name === modelData) ?? {
                                name: modelData
                            }))
                            value: ({
                                    mirror: modelData
                                })
                        }
                    }
                }
            }
        }

        // Night light
        SectionHeader {
            text: Tr.tr("Night light")
        }

        ToggleRow {
            first: true
            last: !checked
            text: Tr.tr("Night light")
            subtext: DesktopSettings.nightLightActive ? Tr.tr("On now: warmer colours, easier on the eyes at night") : Tr.tr("Warmer colours, easier on the eyes at night")
            checked: DesktopSettings.nightLight.enabled
            onToggled: DesktopSettings.nightLight.enabled = checked
        }

        SelectRow {
            visible: DesktopSettings.nightLight.enabled
            label: Tr.tr("When")
            subtext: DesktopSettings.nightLight.schedule === "sun" ? Tr.tr("Today: %1 to %2").arg(DesktopSettings.sunset).arg(DesktopSettings.sunrise) : ""
            menuItems: [nlSun, nlCustom, nlAlways]
            active: menuItems.find(i => i.value === DesktopSettings.nightLight.schedule) ?? nlSun
            onSelected: item => DesktopSettings.nightLight.schedule = item.value

            MenuItem {
                id: nlSun

                text: Tr.tr("Sunset to sunrise")
                value: "sun"
            }
            MenuItem {
                id: nlCustom

                text: Tr.tr("Set times")
                value: "custom"
            }
            MenuItem {
                id: nlAlways

                text: Tr.tr("All the time")
                value: "always"
            }
        }

        TextFieldRow {
            visible: DesktopSettings.nightLight.enabled && DesktopSettings.nightLight.schedule === "custom"
            smallField: true
            label: Tr.tr("Turns on at")
            subtext: Tr.tr("24-hour time, like 20:00")
            value: DesktopSettings.nightLight.from
            onEditingFinished: v => {
                if (root.isValidTime(v))
                    DesktopSettings.nightLight.from = v;
            }
        }

        TextFieldRow {
            visible: DesktopSettings.nightLight.enabled && DesktopSettings.nightLight.schedule === "custom"
            smallField: true
            label: Tr.tr("Turns off at")
            subtext: Tr.tr("24-hour time, like 07:00")
            value: DesktopSettings.nightLight.to
            onEditingFinished: v => {
                if (root.isValidTime(v))
                    DesktopSettings.nightLight.to = v;
            }
        }

        // Warmth: 0 = 5500 K (a touch warm), 1 = 2500 K (very warm).
        SliderRow {
            visible: DesktopSettings.nightLight.enabled
            last: true
            icon: "wb_twilight"
            label: Tr.tr("Warmth")
            valueLabel: `${DesktopSettings.nightLight.temperature} K`
            value: (5500 - DesktopSettings.nightLight.temperature) / 3000
            onMoved: v => DesktopSettings.nightLight.temperature = Math.round((5500 - v * 3000) / 100) * 100
        }
    }
}
