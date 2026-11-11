// Renders the sign-in theme with stand-ins for what SDDM gives a theme, and saves a PNG, so the
// theme can be checked without a sign-in screen to look at. `just signin-preview` runs it inside the
// built image; add `-- --failed` to see the wrong-password state.
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 1920
    height: 1080
    visible: true
    color: "black"

    property bool failed: Qt.application.arguments.indexOf("--failed") >= 0

    property QtObject sddm: QtObject {
        signal loginFailed()
        signal loginSucceeded()
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        function login(user, password, session) { console.log("login", user, session) }
        function suspend() {}
        function reboot() {}
        function powerOff() {}
    }
    property ListModel userModel: ListModel {
        ListElement { name: "alex"; realName: "Alex Rivera"; icon: "" }
    }
    property ListModel sessionModel: ListModel {
        ListElement { name: "SuperAwesomeMagical" }
    }
    property QtObject config: QtObject {
        property string background: "file:///wp/aurora.jpg"
        property string font: "Lexend"
    }
    property QtObject keyboard: QtObject { property bool capsLock: false }

    Loader {
        id: loader
        anchors.fill: parent
        source: "file:///theme/Main.qml"
        onStatusChanged: if (status === Loader.Error) { console.log("LOAD ERROR"); Qt.exit(2) }
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: {
            if (win.failed) win.sddm.loginFailed()
            shot.start()
        }
    }
    Timer {
        id: shot
        interval: 1200
        onTriggered: loader.item.grabToImage(function (result) {
            result.saveToFile(win.failed ? "/out/sddm-failed.png" : "/out/sddm.png")
            Qt.quit()
        })
    }
}
