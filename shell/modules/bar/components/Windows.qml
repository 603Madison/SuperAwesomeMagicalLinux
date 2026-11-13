pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

// The taskbar: an icon for each window on this screen's workspace, and for the minimized ones
// (faded). Click one to bring it to the front, click the one in front to minimize it, click a
// minimized one to bring it back here; middle-click closes it. Minimizing puts a window in the
// "minimized" special workspace (see hypr/desktop.lua).
StyledRect {
    id: root

    required property ShellScreen screen

    readonly property string minimizedWorkspace: "special:minimized"
    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property int wsId: monitor?.activeWorkspace?.id ?? Hypr.activeWsId
    readonly property list<HyprlandToplevel> windows: Hypr.toplevels.values.filter(t => {
        const ws = t.workspace;
        return ws && !Hypr.isToplevelIgnored(t) && (ws.id === root.wsId || ws.name === root.minimizedWorkspace);
    })
    readonly property int nonAnimHeight: windows.length > 0 ? layout.implicitHeight + Tokens.padding.small * 2 : 0

    function select(window: var, address: string, minimized: bool): void {
        const target = `{ window = "address:${address}" }`;
        if (minimized) {
            Hypr.dispatch(`hl.dsp.window.move({ window = "address:${address}", workspace = "${wsId}" })`);
            Hypr.dispatch(`hl.dsp.focus(${target})`);
            Hypr.dispatch("hl.dsp.window.bring_to_top()");
        } else if (Hypr.activeToplevel === window) {
            Hypr.dispatch(`hl.dsp.window.move({ window = "address:${address}", workspace = "${minimizedWorkspace}", follow = false })`);
        } else {
            Hypr.dispatch(`hl.dsp.focus(${target})`);
            Hypr.dispatch("hl.dsp.window.bring_to_top()");
        }
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: nonAnimHeight
    visible: windows.length > 0
    radius: Tokens.rounding.full
    color: Colours.tPalette.m3surfaceContainer

    Behavior on implicitHeight {
        Anim {}
    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: ScriptModel {
                values: root.windows
            }

            delegate: StyledRect {
                id: item

                required property HyprlandToplevel modelData
                readonly property string address: {
                    const a = modelData.lastIpcObject?.address ?? modelData.address;
                    return a.startsWith("0x") ? a : `0x${a}`;
                }
                readonly property bool minimized: modelData.workspace?.name === root.minimizedWorkspace
                readonly property bool focused: !minimized && Hypr.activeToplevel === modelData

                implicitWidth: root.implicitWidth - Tokens.padding.small * 2
                implicitHeight: implicitWidth
                radius: Tokens.rounding.full
                color: focused ? Colours.palette.m3primaryContainer : "transparent"

                Behavior on color {
                    CAnim {}
                }

                CachingIconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.round(parent.width * 0.6)
                    source: Icons.getAppIcon(item.modelData.lastIpcObject?.class ?? "", "application-x-executable")
                    opacity: item.minimized ? 0.4 : 1

                    Behavior on opacity {
                        Anim {}
                    }
                }

                StateLayer {
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    radius: Tokens.rounding.full
                    onClicked: event => {
                        if (event.button === Qt.MiddleButton)
                            Hypr.dispatch(`hl.dsp.window.close({ window = "address:${item.address}" })`);
                        else
                            root.select(item.modelData, item.address, item.minimized);
                    }
                }
            }
        }
    }
}
