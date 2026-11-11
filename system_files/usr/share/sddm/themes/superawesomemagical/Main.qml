// SuperAwesomeMagicalLinux's sign-in screen (SDDM, Qt 6).
//
// The ecosystem's look: Lexend throughout, a big light clock like Weather's temperature, and one
// rounded slate card over the blurred wallpaper. Colours are the shared dark slate scheme with
// the brand's aurora purple and green as accents; theme.conf can change them and the wallpaper.

import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: c.background

    // The brand's dark scheme (the apps' BrandDarkColors; "ink" is Material's on- colours, since QML
    // reads property names starting with "on" as signal handlers).
    QtObject {
        id: c
        readonly property color background: "#0B1220"
        readonly property color surface: "#131D30"
        readonly property color surfaceHigh: "#1A2539"
        readonly property color surfaceHighest: "#223047"
        readonly property color ink: "#E5E9F0"
        readonly property color inkMuted: "#A9B4C6"
        readonly property color outline: "#3B4A63"
        readonly property color outlineVariant: "#263349"
        readonly property color primary: config.accent || "#CFBDFF"
        readonly property color primaryInk: config.onAccent || "#341A86"
        readonly property color secondary: config.secondAccent || "#6EF2B0"
        readonly property color error: "#FF8A80"
    }

    readonly property string font: config.font || "Lexend"
    readonly property string icons: "Material Symbols Rounded"
    property date now: new Date()
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property string message: ""
    // The current account and session, from the Repeaters below.
    readonly property Item user: users.count > 0 ? users.itemAt(Math.min(userIndex, users.count - 1)) : null
    readonly property Item session: sessions.count > 0 ? sessions.itemAt(Math.min(sessionIndex, sessions.count - 1)) : null

    function login() {
        if (busy) return
        busy = true
        message = ""
        sddm.login(root.user ? root.user.userName : "", password.text, sessionIndex)
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

    // SDDM's accounts and sessions, one invisible item each (a Repeater makes them all, visible or
    // not), so the current one's details are easy to reach.
    Item {
        visible: false
        Repeater {
            id: users
            model: userModel
            delegate: Item {
                required property string name
                required property string realName
                required property string icon
                readonly property string userName: name
                readonly property string displayName: realName || name
                readonly property string avatar: icon
            }
        }
        Repeater {
            id: sessions
            model: sessionModel
            delegate: Item {
                required property string name
                readonly property string sessionName: name
            }
        }
    }

    // 12-hour like the apps, without AM/PM (like a phone's lock screen); clock24=true in theme.conf
    // for 24-hour.
    function clockText(d) {
        if (String(config.clock24) === "true")
            return Qt.formatTime(d, "HH:mm")
        return ((d.getHours() + 11) % 12 + 1) + ":" + Qt.formatTime(d, "mm")
    }

    // ---- Backdrop: the wallpaper, softly blurred and dimmed towards the bottom ----

    // The plain wallpaper underneath, so it shows even where the blur can't be drawn.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
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
            text: root.clockText(root.now)
            color: c.ink
            font { family: root.font; weight: Font.Light; pixelSize: Math.round(root.height * 0.13); letterSpacing: -2 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, MMMM d")
            color: c.inkMuted
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

            // Avatar, or the first letter of the name, ringed in the aurora green.
            Item {
                width: 88
                height: 88
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(c.secondary, 0.14)
                    border.color: Qt.alpha(c.secondary, 0.6)
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: (root.user ? root.user.displayName : "").charAt(0).toUpperCase()
                        color: c.secondary
                        font { family: root.font; weight: Font.DemiBold; pixelSize: 38 }
                    }
                }
                Image {
                    id: avatarImage
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.user && root.user.avatar ? root.user.avatar : ""
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
                    visible: users.count > 1
                    glyph: "chevron_left"
                    onClicked: root.userIndex = (root.userIndex + users.count - 1) % users.count
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.user ? root.user.displayName : ""
                    color: c.ink
                    font { family: root.font; weight: Font.DemiBold; pixelSize: 22 }
                }
                IconButton {
                    visible: users.count > 1
                    glyph: "chevron_right"
                    onClicked: root.userIndex = (root.userIndex + 1) % users.count
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
                    color: c.inkMuted
                    font { family: root.icons; pixelSize: 22 }
                }
                TextInput {
                    id: password
                    anchors { left: lockGlyph.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: c.ink
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
                        color: c.inkMuted
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
                    color: c.primaryInk
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
                color: root.message.length > 0 ? c.error : c.inkMuted
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
            label: root.session ? root.session.sessionName : ""
            visible: sessions.count > 0
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessions.count
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
            color: c.inkMuted
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
                color: c.ink
                font { family: root.icons; pixelSize: 20 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: c.ink
                font { family: root.font; weight: Font.Medium; pixelSize: 14 }
            }
        }
        MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }
}
