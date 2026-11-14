pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Mouse, touchpad and keyboard: Hyprland's input options, through DesktopSettings (which shows
// what Hyprland has now until something's chosen, and applies changes at once).
PageBase {
    id: root

    // Every keyboard layout, from XKB's list, as { id: "us", label: "English (US)" }.
    property var allLayouts: []
    readonly property list<string> layouts: String(DesktopSettings.option("input:kb_layout", "us")).split(",").map(l => l.trim()).filter(l => l)
    readonly property list<string> kbOptions: String(DesktopSettings.option("input:kb_options", "")).split(",").map(o => o.trim()).filter(o => o)

    function opt(key: string, fallback: var): var {
        return DesktopSettings.option(key, fallback);
    }

    function flag(key: string, fallback: bool): bool {
        const v = opt(key, fallback);
        return v === true || v === 1 || v === "true" || v === "1";
    }

    function set(key: string, value: var): void {
        DesktopSettings.setOption(key, value);
    }

    function layoutName(id: string): string {
        return allLayouts.find(l => l.id === id)?.label ?? id;
    }

    // kb_options holds several choices at once; this swaps the one in a group ("grp:" for how to
    // switch layouts, "caps:" for Caps Lock) for another, or takes it out.
    function setKbOption(prefix: string, value: string): void {
        const next = kbOptions.filter(o => !o.startsWith(prefix));
        if (value)
            next.push(value);
        set("input:kb_options", next.join(","));
    }

    function kbOptionIn(prefix: string): string {
        return kbOptions.find(o => o.startsWith(prefix)) ?? "";
    }

    title: Tr.tr("Mouse & keyboard")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        FileView {
            path: "/usr/share/X11/xkb/rules/base.lst"
            onLoaded: {
                const section = text().match(/! layout\n([\s\S]*?)\n\n/);
                const list = [];
                for (const line of (section?.[1] ?? "").split("\n")) {
                    const m = line.match(/^\s*([a-z]{2,})\s+(.+)$/);
                    if (m)
                        list.push({
                            id: m[1],
                            label: m[2].trim()
                        });
                }
                root.allLayouts = list.sort((a, b) => a.label.localeCompare(b.label));
            }
        }

        // Mouse
        SectionHeader {
            first: true
            text: Tr.tr("Mouse and pointer")
        }

        // sensitivity runs from -1 to 1
        SliderRow {
            first: true
            icon: "speed"
            label: Tr.tr("Pointer speed")
            valueLabel: {
                const s = Number(root.opt("input:sensitivity", 0));
                return s === 0 ? Tr.tr("Normal") : s < 0 ? Tr.tr("Slower") : Tr.tr("Faster");
            }
            value: (Number(root.opt("input:sensitivity", 0)) + 1) / 2
            onMoved: v => root.set("input:sensitivity", Math.round((v * 2 - 1) * 20) / 20)
        }

        ToggleRow {
            text: Tr.tr("Pointer acceleration")
            subtext: Tr.tr("Moving faster takes the pointer further; off for games and drawing")
            checked: root.opt("input:accel_profile", "") !== "flat"
            onToggled: root.set("input:accel_profile", checked ? "adaptive" : "flat")
        }

        ToggleRow {
            text: Tr.tr("Natural scrolling with a mouse")
            subtext: Tr.tr("The page follows the wheel, as on a phone")
            checked: root.flag("input:natural_scroll", false)
            onToggled: root.set("input:natural_scroll", checked)
        }

        ToggleRow {
            last: true
            text: Tr.tr("Left-handed")
            subtext: Tr.tr("Swaps the left and right buttons")
            checked: root.flag("input:left_handed", false)
            onToggled: root.set("input:left_handed", checked)
        }

        // Touchpad
        SectionHeader {
            text: Tr.tr("Touchpad")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Tap to click")
            subtext: Tr.tr("Tap with one finger to click, two to right-click")
            checked: root.flag("input:touchpad:tap_to_click", true)
            onToggled: root.set("input:touchpad:tap_to_click", checked)
        }

        ToggleRow {
            text: Tr.tr("Natural scrolling")
            subtext: Tr.tr("The page follows your fingers, as on a phone")
            checked: root.flag("input:touchpad:natural_scroll", true)
            onToggled: root.set("input:touchpad:natural_scroll", checked)
        }

        ToggleRow {
            text: Tr.tr("Right-click with two fingers")
            subtext: Tr.tr("Press down with two fingers anywhere, instead of in the corner")
            checked: root.flag("input:touchpad:clickfinger_behavior", false)
            onToggled: root.set("input:touchpad:clickfinger_behavior", checked)
        }

        ToggleRow {
            text: Tr.tr("Ignore the touchpad while typing")
            subtext: Tr.tr("So a palm doesn't move the pointer")
            checked: root.flag("input:touchpad:disable_while_typing", true)
            onToggled: root.set("input:touchpad:disable_while_typing", checked)
        }

        // scroll_factor from 0.25 to 2
        SliderRow {
            last: true
            icon: "swipe_vertical"
            label: Tr.tr("Scrolling speed")
            valueLabel: `${Math.round(Number(root.opt("input:touchpad:scroll_factor", 1)) * 100)}%`
            value: (Number(root.opt("input:touchpad:scroll_factor", 1)) - 0.25) / 1.75
            onMoved: v => root.set("input:touchpad:scroll_factor", Math.round((0.25 + v * 1.75) * 20) / 20)
        }

        // Keyboard
        SectionHeader {
            text: Tr.tr("Keyboard")
        }

        Repeater {
            model: root.layouts

            RowButton {
                required property string modelData
                required property int index

                first: index === 0
                icon: "keyboard"
                text: root.layoutName(modelData)
                subtext: root.layouts.length === 1 ? Tr.tr("Add another to switch between them") : index === 0 ? Tr.tr("Used at first; click to remove") : Tr.tr("Click to remove")
                trailingIcon: root.layouts.length > 1 ? "close" : ""
                onClicked: {
                    if (root.layouts.length > 1)
                        root.set("input:kb_layout", root.layouts.filter(l => l !== modelData).join(","));
                }
            }
        }

        DialogSelectButton {
            Layout.fillWidth: true
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add a keyboard layout")
            header: Tr.tr("Add a keyboard layout")
            acceptLabel: Tr.trCtx("Add", "button")
            model: root.allLayouts.filter(l => !root.layouts.includes(l.id))
            onAccepted: {
                if (selectedItem)
                    root.set("input:kb_layout", [...root.layouts, selectedItem].join(","));
            }
        }

        SelectRow {
            visible: root.layouts.length > 1
            label: Tr.tr("Switch layouts with")
            menuItems: [swAltShift, swSuperSpace, swCaps, swCtrlShift]
            active: menuItems.find(i => i.value === root.kbOptionIn("grp:")) ?? null
            fallbackText: Tr.tr("The bar's layout button")
            onSelected: item => root.setKbOption("grp:", item.value)

            MenuItem {
                id: swAltShift

                text: Tr.tr("Alt + Shift")
                value: "grp:alt_shift_toggle"
            }
            MenuItem {
                id: swSuperSpace

                text: Tr.tr("Super + Space")
                value: "grp:win_space_toggle"
            }
            MenuItem {
                id: swCtrlShift

                text: Tr.tr("Ctrl + Shift")
                value: "grp:ctrl_shift_toggle"
            }
            MenuItem {
                id: swCaps

                text: Tr.tr("Caps Lock")
                value: "grp:caps_toggle"
            }
        }

        SelectRow {
            label: Tr.tr("Caps Lock key")
            menuItems: [capsNormal, capsCtrl, capsEsc, capsBackspace]
            active: menuItems.find(i => i.value === root.kbOptionIn("caps:") + root.kbOptionIn("ctrl:nocaps")) ?? capsNormal
            onSelected: item => {
                const next = root.kbOptions.filter(o => !o.startsWith("caps:") && o !== "ctrl:nocaps");
                if (item.value)
                    next.push(item.value);
                root.set("input:kb_options", next.join(","));
            }

            MenuItem {
                id: capsNormal

                text: Tr.tr("Caps Lock")
                value: ""
            }
            MenuItem {
                id: capsCtrl

                text: Tr.tr("Another Ctrl")
                value: "ctrl:nocaps"
            }
            MenuItem {
                id: capsEsc

                text: Tr.tr("Escape")
                value: "caps:escape"
            }
            MenuItem {
                id: capsBackspace

                text: Tr.tr("Backspace")
                value: "caps:backspace"
            }
        }

        // repeat_delay in ms, 150 to 1000
        SliderRow {
            icon: "keyboard_tab"
            label: Tr.tr("Delay before keys repeat")
            valueLabel: `${root.opt("input:repeat_delay", 250)} ms`
            value: (Number(root.opt("input:repeat_delay", 250)) - 150) / 850
            onMoved: v => root.set("input:repeat_delay", Math.round((150 + v * 850) / 10) * 10)
        }

        // repeat_rate per second, 10 to 60
        SliderRow {
            icon: "fast_forward"
            label: Tr.tr("Repeat speed")
            valueLabel: Tr.tr("%1 a second").arg(root.opt("input:repeat_rate", 35))
            value: (Number(root.opt("input:repeat_rate", 35)) - 10) / 50
            onMoved: v => root.set("input:repeat_rate", Math.round(10 + v * 50))
        }

        ToggleRow {
            last: true
            text: Tr.tr("Num Lock on at start")
            checked: root.flag("input:numlock_by_default", false)
            onToggled: root.set("input:numlock_by_default", checked)
        }
    }
}
