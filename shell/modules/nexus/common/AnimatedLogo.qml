pragma ComponentBehavior: Bound

import QtQuick
import qs.components

// The SuperAwesomeMagical mark (components/Logo.qml) with an intro: the big sparkle spins and
// swells in, then the small one pops in beside it with a twinkle.
Item {
    id: root

    property bool skipIntroAnimation: false

    signal animationCompleted

    implicitWidth: 128
    implicitHeight: 128

    Logo {
        id: logo

        anchors.fill: parent
        bigScale: root.skipIntroAnimation ? 1 : 0
        bigRotation: root.skipIntroAnimation ? 0 : -90
        smallScale: root.skipIntroAnimation ? 1 : 0
    }

    SequentialAnimation {
        running: !root.skipIntroAnimation

        ParallelAnimation {
            NumberAnimation {
                target: logo
                property: "bigScale"
                to: 1.08
                duration: 520
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: logo
                property: "bigRotation"
                to: 0
                duration: 620
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation {
            target: logo
            property: "bigScale"
            to: 1
            duration: 200
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: logo
            property: "smallScale"
            to: 1.35
            duration: 220
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: logo
            property: "smallScale"
            to: 1
            duration: 260
            easing.type: Easing.InOutSine
        }
        ScriptAction {
            script: root.animationCompleted()
        }
    }
}
