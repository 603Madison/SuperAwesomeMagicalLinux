pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property var lock

    anchors.fill: parent
    anchors.margins: Tokens.padding.large

    spacing: Tokens.spacing.medium

    StyledText {
        Layout.fillWidth: true
        text: Notifs.list.length > 0 ? Tr.trN("%n notification", "%n notifications", Notifs.list.length) : Tr.tr("Notifications")
        color: Colours.palette.m3outline
        font: Tokens.font.mono.builders.small.weight(Font.Medium).build()
        elide: Text.ElideRight
    }

    ClippingRectangle {
        id: clipRect

        Layout.fillWidth: true
        Layout.fillHeight: true

        radius: Tokens.rounding.medium
        color: "transparent"

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            active: opacity > 0
            opacity: Notifs.list.length > 0 && !Config.lock.hideNotifs ? 0 : 1

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.largeIncreased

                // A calm mark instead of a picture: a tick (or a lock) in a soft circle.
                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Tokens.sizes.dashboard.logoSize * 2.4
                    implicitHeight: implicitWidth
                    radius: implicitWidth / 2
                    color: Colours.tPalette.m3surfaceContainerHigh

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Config.lock.hideNotifs ? "lock" : "done_all"
                        color: Config.lock.hideNotifs ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3secondary
                        fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.3).build()
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Config.lock.hideNotifs ? Tr.tr("Unlock to see notifications") : Tr.tr("You're all caught up")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardExtraLarge
                }
            }
        }

        StyledListView {
            anchors.fill: parent
            visible: !Config.lock.hideNotifs
            spacing: Tokens.spacing.small
            clip: true

            model: ScriptModel {
                values: {
                    const list = Notifs.notClosed.map(n => [n.appName, null]);
                    return [...new Map(list).keys()];
                }
            }

            delegate: NotifGroup {}

            add: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    from: 0
                    to: 1
                }
                Anim {
                    property: "scale"
                    from: 0
                    to: 1
                }
            }

            remove: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 0
                }
                Anim {
                    property: "scale"
                    to: 0.6
                }
            }

            move: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    properties: "opacity,scale"
                    to: 1
                }
                Anim {
                    property: "y"
                }
            }

            displaced: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    properties: "opacity,scale"
                    to: 1
                }
                Anim {
                    property: "y"
                }
            }
        }
    }
}
