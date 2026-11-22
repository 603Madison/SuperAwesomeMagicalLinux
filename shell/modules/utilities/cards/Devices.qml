import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

// Your other devices at a glance (services/Orchestrator.qml): the phone (or whichever other device
// is here) with its battery and a button to ring it, and the newest thing to carry on with from
// another device. Only there for people who are signed in and have another device; everything else
// is in Settings › Your devices, which a click on the card opens.
StyledRect {
    id: root

    // The phone if it's here, else another device that is, else any other.
    readonly property var device: {
        const others = Orchestrator.otherDevices;
        return others.find(d => d.online && d.kind === "ANDROID") ?? others.find(d => d.online) ?? others[0] ?? null;
    }
    readonly property var activity: Orchestrator.activities.find(a => Orchestrator.mayOpen(a.url)) ?? null
    readonly property bool ringing: device ? Orchestrator.isRinging(device.id) : false
    readonly property bool canRing: (device?.capabilities ?? []).length === 0 || device.capabilities.includes("ring")
    readonly property real nonAnimHeight: layout.implicitHeight + Tokens.padding.large * 2

    implicitHeight: nonAnimHeight

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    StateLayer {
        onClicked: {
            if (root.activity)
                Orchestrator.open(root.activity.url);
            else
                WindowFactory.create(null, {
                    startPage: Math.max(0, PageRegistry.pages.findIndex(p => p.id === "yourdevices"))
                });
        }
    }

    RowLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Tokens.padding.large

            radius: Tokens.rounding.full
            color: root.device?.online ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                text: root.device?.kind === "ANDROID" ? "smartphone" : root.device?.kind === "LINUX" ? "computer" : "devices"
                color: root.device?.online ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                fontStyle: Tokens.font.icon.large
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: {
                    const name = root.device?.name ?? "";
                    // TRANSLATORS: %1 = a device's name, %2 = its battery level
                    return root.device?.battery ? Tr.tr("%1 · %2%").arg(name).arg(root.device.battery.level) : name;
                }
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (root.activity)
                        // TRANSLATORS: %1 = what's playing or open on another device
                        return Tr.tr("Carry on: %1").arg(root.activity.title);
                    return root.device?.online ? Tr.tr("Connected") : Tr.tr("Away");
                }
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        IconTextButton {
            visible: root.canRing
            type: root.ringing ? IconTextButton.Filled : IconTextButton.Tonal
            icon: root.ringing ? "notifications_off" : "notifications_active"
            text: root.ringing ? Tr.tr("Stop") : Tr.tr("Ring")
            onClicked: Orchestrator.ring(root.device.id, !root.ringing)
        }
    }
}
