import QtQuick
import QtQuick.Shapes
import qs.services

// The SuperAwesomeMagical mark: an S of two aurora ribbons (purple over green) with a sparkle.
// The same drawing is the OS logo in /usr/share/icons/hicolor/scalable/apps/superawesomemagical.svg.
Item {
    id: root

    readonly property real designWidth: 128
    readonly property real designHeight: 128
    readonly property real ribbonWidth: 17

    property color topColour: Colours.palette.m3primary
    property color bottomColour: Colours.palette.m3secondary
    property color sparkleColour: topColour

    implicitWidth: designWidth
    implicitHeight: designHeight

    Shape {
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        // Top ribbon
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.topColour
            strokeWidth: root.ribbonWidth
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M88 34 A26 26 0 1 0 62 64"
            }
        }

        // Bottom ribbon
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.bottomColour
            strokeWidth: root.ribbonWidth
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M62 64 A26 26 0 1 1 36 94"
            }
        }

        // Sparkle
        ShapePath {
            fillColor: root.sparkleColour
            strokeColor: "transparent"

            PathSvg {
                path: "M108 6 C110 18 112 20 124 22 C112 24 110 26 108 38 C106 26 104 24 92 22 C104 20 106 18 108 6 Z"
            }
        }
    }
}
