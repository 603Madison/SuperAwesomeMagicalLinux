// SuperAwesomeMagicalLinux's sign-in screen (SDDM, Qt 6).
//
// The ecosystem's look: Lexend throughout, a big light clock like Weather's temperature, and one
// rounded slate card over the blurred wallpaper. Colours are the shared dark slate scheme with
// Weather's blue as the accent; theme.conf can change the accent and wallpaper.

import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: c.background

    // The brand's dark scheme (the same tokens as the apps' BrandDarkColors).
    QtObject {
        id: c
        readonly property color background: "#0B1220"
        readonly property color surface: "#131D30"
        readonly property color surfaceHigh: "#1A2539"
        readonly property color surfaceHighest: "#223047"
        readonly property color onSurface: "#E5E9F0"
        readonly property color onSurfaceVariant: "#A9B4C6"
        readonly property color outline: "#3B4A63"
        readonly property color outlineVariant: "#263349"
        readonly property color primary: config.accent || "#8DB4FF"
        readonly property color onPrimary: config.onAccent || "#0A1E4A"
        readonly property color error: "#FF8A80"
    }

    readonly property string font: config.font || "Lexend"
    readonly property string icons: "Material Symbols Rounded"
    property date now: new Date()
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property string message: ""

    function login() {
        if (busy) return
        busy = true
        message = ""
        sddm.login(users.currentItem.userName, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.message = "That password didn't work. Try again."
            password.text = ""
            password.forceActiveFocus()
            shake.restart()
        }
        function onLoginSucceeded() { root.message = "" }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Models read through invisible views, so the current user's and session's roles are easy to reach.
    ListView {
        id: users
        visible: false
        model: userModel
        currentIndex: root.userIndex
        delegate: Item {
            property string userName: model.name
            property string displayName: model.realName || model.name
            property string avatar: model.icon || ""
        }
    }
    ListView {
        id: sessions
        visible: false
        model: sessionModel
        currentIndex: root.sessionIndex
        delegate: Item { property string sessionName: model.name }
    }

    // ---- Backdrop: the wallpaper, softly blurred and dimmed towards the bottom ----

    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 0.55
        blurMax: 48
        brightness: -0.08
        saturation: 0.1
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(c.background, 0.25) }
            GradientStop { position: 1.0; color: Qt.alpha(c.background, 0.75) }
        }
    }

    // ---- Clock ----

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.12
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, config.clockFormat || "h:mm")
            color: c.onSurface
            font { family: root.font; weight: Font.Light; pixelSize: Math.round(root.height * 0.13); letterSpacing: -2 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, MMMM d")
            color: c.onSurfaceVariant
            font { family: root.font; weight: Font.Medium; pixelSize: Math.round(root.height * 0.024) }
        }
    }

    // ---- Sign-in card ----

    Rectangle {
        id: card
        width: 400
        height: content.implicitHeight + 64
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.5 - 40
        radius: 28
        color: Qt.alpha(c.surface, 0.88)
        border.color: c.outlineVariant
        border.width: 1

        SequentialAnimation {
            id: shake
            loops: 1
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 10; duration: 70 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
        }

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 32 }
            spacing: 16

            // Avatar, or the first letter of the name on the accent.
            Item {
                width: 88
                height: 88
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(c.primary, 0.18)
                    border.color: Qt.alpha(c.primary, 0.5)
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: (users.currentItem ? users.currentItem.displayName : "?").charAt(0).toUpperCase()
                        color: c.primary
                        font { family: root.font; weight: Font.DemiBold; pixelSize: 38 }
                    }
                }
                Image {
                    id: avatarImage
                    anchors.fill: parent
                    anchors.margins: 2
                    source: users.currentItem && users.currentItem.avatar ? users.currentItem.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                MultiEffect {
                    anchors.fill: avatarImage
                    source: avatarImage
                    visible: avatarImage.status === Image.Ready
                    maskEnabled: true
                    maskSource: avatarMask
                }
                Item {
                    id: avatarMask
                    anchors.fill: avatarImage
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: width / 2 }
                }
            }

            // Name, with arrows to switch when there's more than one account.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                IconButton {
                    visible: userModel.count > 1
                    glyph: "chevron_left"
                    onClicked: root.userIndex = (root.userIndex + userModel.count - 1) % userModel.count
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: users.currentItem ? users.currentItem.displayName : ""
                    color: c.onSurface
                    font { family: root.font; weight: Font.DemiBold; pixelSize: 22 }
                }
                IconButton {
                    visible: userModel.count > 1
                    glyph: "chevron_right"
                    onClicked: root.userIndex = (root.userIndex + 1) % userModel.count
                }
            }

            // Password.
            Rectangle {
                width: parent.width
                height: 52
                radius: 16
                color: c.surfaceHigh
                border.color: password.activeFocus ? c.primary : c.outlineVariant
                border.width: password.activeFocus ? 2 : 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    id: lockGlyph
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    text: "lock"
                    color: c.onSurfaceVariant
                    font { family: root.icons; pixelSize: 22 }
                }
                TextInput {
                    id: password
                    anchors { left: lockGlyph.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: c.onSurface
                    selectionColor: Qt.alpha(c.primary, 0.4)
                    font { family: root.font; pixelSize: 17; letterSpacing: 1 }
                    focus: true
                    clip: true
                    enabled: !root.busy
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !password.text
                        text: "Password"
                        color: c.onSurfaceVariant
                        font { family: root.font; pixelSize: 16 }
                    }
                }
            }

            // Sign in.
            Rectangle {
                width: parent.width
                height: 52
                radius: 26
                color: signInArea.pressed ? Qt.darker(c.primary, 1.15) : signInArea.containsMouse ? Qt.lighter(c.primary, 1.06) : c.primary
                Behavior on color { ColorAnimation { duration: 120 } }
                opacity: root.busy ? 0.7 : 1
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "Signing in…" : "Sign in"
                    color: c.onPrimary
                    font { family: root.font; weight: Font.DemiBold; pixelSize: 16 }
                }
                MouseArea {
                    id: signInArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.login()
                }
            }

            Text {
                width: parent.width
                visible: root.message.length > 0 || capsLock.on
                text: root.message.length > 0 ? root.message : "Caps Lock is on"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: root.message.length > 0 ? c.error : c.onSurfaceVariant
                font { family: root.font; weight: Font.Medium; pixelSize: 14 }
                QtObject { id: capsLock; readonly property bool on: keyboard.capsLock }
            }
        }
    }

    // ---- Bottom bar: session on the left, power on the right ----

    Row {
        anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
        spacing: 8
        Chip {
            glyph: "desktop_windows"
            label: sessions.currentItem ? sessions.currentItem.sessionName : ""
            visible: sessionModel.rowCount() > 0
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
        }
    }
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        spacing: 8
        Chip { glyph: "bedtime"; label: "Sleep"; visible: sddm.canSuspend; onClicked: sddm.suspend() }
        Chip { glyph: "restart_alt"; label: "Restart"; visible: sddm.canReboot; onClicked: sddm.reboot() }
        Chip { glyph: "power_settings_new"; label: "Shut down"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }

    // ---- Small building blocks ----

    component IconButton: Rectangle {
        id: btn
        property string glyph
        signal clicked
        width: 36
        height: 36
        radius: 18
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: area.containsMouse ? c.surfaceHighest : "transparent"
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: c.onSurfaceVariant
            font { family: root.icons; pixelSize: 24 }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    component Chip: Rectangle {
        id: chip
        property string glyph
        property string label
        signal clicked
        height: 44
        width: chipRow.implicitWidth + 32
        radius: 22
        color: chipArea.containsMouse ? Qt.alpha(c.surfaceHighest, 0.92) : Qt.alpha(c.surface, 0.78)
        border.color: c.outlineVariant
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                color: c.onSurface
                font { family: root.icons; pixelSize: 20 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: c.onSurface
                font { family: root.font; weight: Font.Medium; pixelSize: 14 }
            }
        }
        MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }
}
