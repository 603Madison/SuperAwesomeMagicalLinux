pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// Where a dragged window will land if it's let go: snapping (Aero Snap) is the title bars plugin's
// (build_files/titlebars/snap.cpp), which sends "samsnap>>x,y,w,h" in Hyprland's global layout
// coordinates while a drag is over an edge or corner, and "samsnap>>" when it leaves.
Scope {
    id: root

    property rect zone
    property bool shown

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "samsnap")
                return;

            const v = event.data.split(",").map(Number);
            if (v.length === 4 && v.every(n => isFinite(n))) {
                root.zone = Qt.rect(v[0], v[1], v[2], v[3]);
                root.shown = true;
            } else {
                root.shown = false;
            }
        }

        target: Hyprland
    }

    Variants {
        model: Screens.screens

        StyledWindow {
            id: win

            required property ShellScreen modelData
            readonly property HyprlandMonitor monitor: Hypr.monitorFor(modelData)
            // The zone in this screen's coordinates, if it's on this screen.
            readonly property bool here: root.shown && monitor && root.zone.x >= monitor.x && root.zone.x < monitor.x + modelData.width && root.zone.y >= monitor.y && root.zone.y < monitor.y + modelData.height

            screen: modelData
            name: "snap"
            // Mapped only while there's a zone to show, and while it fades away.
            visible: here || fadingOut.running
            onHereChanged: {
                if (!here)
                    fadingOut.restart();
            }
            surfaceFormat.opaque: false
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Timer {
                id: fadingOut

                interval: win.Tokens.anim.durations.small
            }

            StyledRect {
                id: box

                property rect last: Qt.rect(0, 0, 0, 0)

                x: last.x
                y: last.y
                width: last.width
                height: last.height
                opacity: win.here ? 1 : 0
                scale: win.here ? 1 : 0.96
                radius: Tokens.rounding.large
                color: Qt.alpha(Colours.palette.m3primary, 0.18)
                border.width: 2
                border.color: Qt.alpha(Colours.palette.m3primary, 0.7)

                Connections {
                    function onHereChanged(): void {
                        if (win.here)
                            box.last = Qt.rect(root.zone.x - win.monitor.x, root.zone.y - win.monitor.y, root.zone.width, root.zone.height);
                    }

                    target: win
                }

                Connections {
                    function onZoneChanged(): void {
                        if (win.here)
                            box.last = Qt.rect(root.zone.x - win.monitor.x, root.zone.y - win.monitor.y, root.zone.width, root.zone.height);
                    }

                    target: root
                }

                Behavior on opacity {
                    Anim {
                        duration: Tokens.anim.durations.small
                    }
                }

                Behavior on scale {
                    Anim {
                        duration: Tokens.anim.durations.small
                    }
                }

                Behavior on x {
                    enabled: win.here && box.opacity > 0.5

                    Anim {}
                }

                Behavior on y {
                    enabled: win.here && box.opacity > 0.5

                    Anim {}
                }

                Behavior on width {
                    enabled: win.here && box.opacity > 0.5

                    Anim {}
                }

                Behavior on height {
                    enabled: win.here && box.opacity > 0.5

                    Anim {}
                }
            }
        }
    }
}
