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

// Date & time: network time (chrony, see build.sh), the time zone (automatic from where the
// network says you are, or chosen), and how times are shown. timedated does the changing; a polkit
// rule lets administrators do it without a password.
PageBase {
    id: root

    // Every time zone, from timedatectl, as { region, city, id }.
    property var zones: []
    readonly property var regions: [...new Set(zones.map(z => z.region))]
    property string pickedRegion: DesktopSettings.timezone.split("/")[0] || "Europe"

    // Clock formats (one for each value of the ClockFormat enum)
    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: ClockFormat.Auto
        },
        MenuItem {
            text: Tr.tr("12-hour")
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: Tr.tr("24-hour")
            value: ClockFormat.TwentyFourHour
        }
    ]

    function cityName(id: string): string {
        return id.split("/").slice(1).join(" / ").replace(/_/g, " ") || id;
    }

    title: Tr.tr("Date & time")

    Component.onCompleted: DesktopSettings.refreshTime()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            running: true
            command: ["timedatectl", "list-timezones"]
            stdout: StdioCollector {
                onStreamFinished: root.zones = text.trim().split("\n").filter(id => id.includes("/") && !id.startsWith("Etc/")).map(id => ({
                            region: id.split("/")[0],
                            city: root.cityName(id),
                            id
                        }))
            }
        }

        // Look again now and then, to show when the clock gets in step.
        Timer {
            running: true
            repeat: true
            interval: 10000
            onTriggered: DesktopSettings.refreshTime()
        }

        // The time
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: now.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: now

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.largeIncreased * 2
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format(Units.twelveHourClock ? "h:mm A" : "HH:mm")
                    color: Colours.palette.m3primary
                    font: Tokens.font.headline.medium
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("dddd d MMMM yyyy")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.title.small
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.small
                    text: DesktopSettings.timezone.replace(/_/g, " ")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.medium
                }
            }
        }

        // Network time
        SectionHeader {
            text: Tr.tr("Time")
        }

        ToggleRow {
            first: true
            last: !checked
            text: Tr.tr("Set the time automatically")
            subtext: !checked ? Tr.tr("The clock keeps its own time") : DesktopSettings.ntpSynced ? Tr.tr("In step with %1").arg(DesktopSettings.timeServer || Tr.tr("the time servers")) : Tr.tr("Getting in step with the time servers…")
            checked: DesktopSettings.ntp
            onToggled: DesktopSettings.setNtp(checked)
        }

        RowButton {
            visible: DesktopSettings.ntp
            last: true
            icon: "sync"
            text: Tr.tr("Check the time now")
            subtext: Tr.tr("Asks the time servers again and puts the clock right")
            onClicked: DesktopSettings.syncNow()
        }

        // Time zone
        SectionHeader {
            text: Tr.tr("Time zone")
        }

        ToggleRow {
            first: true
            last: checked
            text: Tr.tr("Set the time zone automatically")
            subtext: Tr.tr("From where your network says you are, also when you travel")
            checked: DesktopSettings.time.autoTimezone
            onToggled: DesktopSettings.time.autoTimezone = checked
        }

        SelectRow {
            visible: !DesktopSettings.time.autoTimezone
            label: Tr.tr("Region")
            menuItems: regionItems.instances
            active: menuItems.find(i => i.value === root.pickedRegion) ?? null
            fallbackText: root.pickedRegion
            onSelected: item => root.pickedRegion = item.value

            Variants {
                id: regionItems

                model: root.regions

                MenuItem {
                    required property string modelData

                    text: modelData
                    value: modelData
                }
            }
        }

        DialogSelectButton {
            Layout.fillWidth: true
            visible: !DesktopSettings.time.autoTimezone
            rootParent: root.flickable
            icon: "location_city"
            label: DesktopSettings.timezone.startsWith(root.pickedRegion + "/") ? Tr.tr("City: %1").arg(root.cityName(DesktopSettings.timezone)) : Tr.tr("Choose a city")
            header: Tr.tr("Time zone in %1").arg(root.pickedRegion)
            acceptLabel: Tr.tr("Use")
            model: root.zones.filter(z => z.region === root.pickedRegion).map(z => ({
                        id: z.id,
                        label: z.city
                    }))
            onAccepted: {
                if (selectedItem)
                    DesktopSettings.setTimezone(selectedItem, true);
            }
        }

        // How times look
        SectionHeader {
            text: Tr.tr("Format")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Clock format")
            subtext: Tr.tr("How times are shown across the desktop")
            menuItems: root.clockItems
            active: root.clockItems.find(i => i.value === GlobalConfig.services.clockFormat)
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }
    }
}
