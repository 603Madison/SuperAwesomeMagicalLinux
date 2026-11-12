import QtQuick
import QtQuick.Shapes
import qs.services

// The SuperAwesomeMagical mark: a big four-point sparkle fading from the aurora's purple into its
// green, with a small green sparkle beside it, in a 128 x 128 design. The same drawing is the OS
// logo in /usr/share/icons/hicolor/scalable/apps/superawesomemagical.svg and the boot splash's
// (build_files/plymouth.py).
Item {
    id: root

    readonly property real designSize: 128

    property color topColour: Colours.palette.m3primary
    property color bottomColour: Colours.palette.m3secondary
    // The deeper violet a little past halfway down the big sparkle.
    readonly property color midColour: Qt.hsla(topColour.hslHue, topColour.hslSaturation, topColour.hslLightness * 0.82, topColour.a)
    property color sparkleColour: bottomColour

    // For AnimatedLogo: each sparkle's scale about its own centre, and the big one's turn.
    property real bigScale: 1
    property real bigRotation: 0
    property real smallScale: 1

    implicitWidth: designSize
    implicitHeight: designSize

    Item {
        anchors.centerIn: parent
        width: root.designSize
        height: root.designSize
        scale: Math.min(root.width / width, root.height / height)

        // The big sparkle, centred on (56, 72).
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: [
                Rotation {
                    origin.x: 56
                    origin.y: 72
                    angle: root.bigRotation
                },
                Scale {
                    origin.x: 56
                    origin.y: 72
                    xScale: root.bigScale
                    yScale: root.bigScale
                }
            ]

            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 12
                    x2: 0
                    y2: 124

                    GradientStop {
                        position: 0
                        color: root.topColour
                    }
                    GradientStop {
                        position: 0.55
                        color: root.midColour
                    }
                    GradientStop {
                        position: 1
                        color: root.bottomColour
                    }
                }

                PathSvg {
                    path: "M56 12 C61 56 72 67 116 72 C72 77 61 88 56 124 C51 88 40 77 4 72 C40 67 51 56 56 12 Z"
                }
            }
        }

        // The small sparkle, centred on (106, 22).
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                origin.x: 106
                origin.y: 22
                xScale: root.smallScale
                yScale: root.smallScale
            }

            ShapePath {
                fillColor: root.sparkleColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M106 4 C108 17 111 20 124 22 C111 24 108 27 106 40 C104 27 101 24 88 22 C101 20 104 17 106 4 Z"
                }
            }
        }
    }
}
