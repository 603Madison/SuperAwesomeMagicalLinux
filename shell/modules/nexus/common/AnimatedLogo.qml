pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.components
import qs.services

// The SuperAwesomeMagical mark (components/Logo.qml) with an intro: the two aurora ribbons draw
// themselves in, then the sparkle pops in and twinkles.
Item {
    id: root

    property bool skipIntroAnimation: false

    // 0..1 how much of each ribbon is drawn, and the sparkle's scale.
    property real topProgress: skipIntroAnimation ? 1 : 0
    property real bottomProgress: skipIntroAnimation ? 1 : 0
    property real sparkleScale: skipIntroAnimation ? 1 : 0

    signal animationCompleted

    implicitWidth: 128
    implicitHeight: 128

    Shape {
        id: shape

        readonly property real ribbonWidth: 17
        // Each ribbon is a 3/4 circle of radius 26.
        readonly property real ribbonLength: 2 * Math.PI * 26 * 0.75

        anchors.centerIn: parent
        width: 128
        height: 128
        scale: Math.min(root.width / width, root.height / height)
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colours.palette.m3primary
            strokeWidth: shape.ribbonWidth
            capStyle: ShapePath.RoundCap
            strokeStyle: ShapePath.DashLine
            dashPattern: [Math.max(root.topProgress * shape.ribbonLength / shape.ribbonWidth, 0.001), 1000]

            PathSvg {
                path: "M88 34 A26 26 0 1 0 62 64"
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colours.palette.m3secondary
            strokeWidth: shape.ribbonWidth
            capStyle: ShapePath.RoundCap
            strokeStyle: ShapePath.DashLine
            dashPattern: [Math.max(root.bottomProgress * shape.ribbonLength / shape.ribbonWidth, 0.001), 1000]

            PathSvg {
                path: "M62 64 A26 26 0 1 1 36 94"
            }
        }
    }

    // The sparkle, on its own so it can scale about its centre (108, 22 in the 128 design).
    Shape {
        width: 32
        height: 32
        x: (108 - 16) * shape.scale + (root.width - 128 * shape.scale) / 2
        y: (22 - 16) * shape.scale + (root.height - 128 * shape.scale) / 2
        scale: root.sparkleScale * shape.scale
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Colours.palette.m3primary
            strokeColor: "transparent"

            PathSvg {
                path: "M16 0 C18 12 20 14 32 16 C20 18 18 20 16 32 C14 20 12 18 0 16 C12 14 14 12 16 0 Z"
            }
        }
    }

    SequentialAnimation {
        running: !root.skipIntroAnimation

        NumberAnimation {
            target: root
            property: "topProgress"
            to: 1
            duration: 520
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "bottomProgress"
            to: 1
            duration: 520
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "sparkleScale"
            to: 1.25
            duration: 220
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: root
            property: "sparkleScale"
            to: 1
            duration: 260
            easing.type: Easing.InOutSine
        }
        ScriptAction {
            script: root.animationCompleted()
        }
    }
}
