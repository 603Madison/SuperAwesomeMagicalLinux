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

// Accessibility: bigger text (the desktop's and apps'), a bigger pointer, and less motion.
PageBase {
    id: root

    readonly property list<MenuItem> textItems: [
        MenuItem {
            text: Tr.tr("Normal")
            value: 1
        },
        MenuItem {
            text: Tr.tr("Larger")
            value: 1.15
        },
        MenuItem {
            text: Tr.tr("Large")
            value: 1.3
        },
        MenuItem {
            text: Tr.tr("Largest")
            value: 1.5
        }
    ]

    readonly property list<MenuItem> cursorItems: [
        MenuItem {
            text: Tr.tr("Normal")
            value: 24
        },
        MenuItem {
            text: Tr.tr("Larger")
            value: 32
        },
        MenuItem {
            text: Tr.tr("Large")
            value: 48
        },
        MenuItem {
            text: Tr.tr("Largest")
            value: 64
        }
    ]

    title: Tr.tr("Accessibility")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Seeing")
        }

        SelectRow {
            first: true
            label: Tr.tr("Text size")
            subtext: Tr.tr("On the desktop and in apps")
            menuItems: root.textItems
            active: menuItems.find(i => Math.abs(i.value - GlobalConfig.appearance.font.scale) < 0.01) ?? null
            fallbackText: `${Math.round(GlobalConfig.appearance.font.scale * 100)}%`
            onSelected: item => {
                GlobalConfig.appearance.font.scale = item.value;
                // GTK apps (Files, Text Editor and the like)
                Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", String(item.value)]);
            }
        }

        SelectRow {
            last: true
            label: Tr.tr("Pointer size")
            menuItems: root.cursorItems
            active: menuItems.find(i => i.value === DesktopSettings.accessibility.cursorSize) ?? null
            fallbackText: String(DesktopSettings.accessibility.cursorSize)
            onSelected: item => DesktopSettings.setCursorSize(item.value)
        }

        SectionHeader {
            text: Tr.tr("Motion")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Reduce motion")
            subtext: Tr.tr("Windows appear and go without sliding, and the desktop's animations are quicker")
            checked: DesktopSettings.accessibility.reduceMotion
            onToggled: DesktopSettings.setReduceMotion(checked)
        }
    }
}
