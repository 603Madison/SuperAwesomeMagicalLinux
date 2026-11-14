pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils
import qs.modules.nexus.common

// Your account: your picture (~/.face, which the sign-in and lock screens and the dashboard show),
// your password, and fingerprints for unlocking (fprintd). The ones that ask for your password run
// in a terminal.
PageBase {
    id: root

    property string fullName
    readonly property string userName: Quickshell.env("USER")

    // Runs a script in a terminal that stays open until Enter.
    function inTerminal(title: string, script: string): void {
        Quickshell.execDetached(["foot", "--title", title, "sh", "-c", `${script}; echo; read -rp '${Tr.tr("Press Enter to close.")} ' _`]);
    }

    title: Tr.tr("Your account")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            running: true
            command: ["getent", "passwd", root.userName]
            stdout: StdioCollector {
                onStreamFinished: root.fullName = (text.split(":")[4] ?? "").split(",")[0]
            }
        }

        FileDialog {
            id: picker

            title: Tr.tr("Choose a picture")
            filterLabel: Tr.tr("Image files")
            filters: Images.validImageExtensions
            onAccepted: path => {
                if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(`${Paths.home}/.face`))) {
                    // Load it again (it isn't cached, but the path is the same).
                    face.source = "";
                    face.source = `file://${Paths.home}/.face`;
                }
            }
        }

        // Who you are
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: who.implicitHeight + Tokens.padding.extraLarge * 2

            RowLayout {
                id: who

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.large

                StyledClippingRect {
                    implicitWidth: 72
                    implicitHeight: 72
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: "person"
                        color: Colours.palette.m3onPrimaryContainer
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    Image {
                        id: face

                        anchors.fill: parent
                        source: `file://${Paths.home}/.face`
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        asynchronous: true
                        sourceSize.width: 144
                        sourceSize.height: 144
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.fullName || root.userName
                        font: Tokens.font.headline.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.userName
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Signing in")
        }

        RowButton {
            first: true
            icon: "account_circle"
            text: Tr.tr("Change your picture")
            subtext: Tr.tr("Shown when you sign in and unlock")
            onClicked: picker.open()
        }

        RowButton {
            icon: "password"
            text: Tr.tr("Change your password")
            subtext: Tr.tr("In a terminal, which asks for the old one first")
            trailingIcon: "open_in_new"
            onClicked: root.inTerminal(Tr.tr("Change your password"), "passwd")
        }

        RowButton {
            icon: "fingerprint"
            text: Tr.tr("Add a fingerprint")
            subtext: Tr.tr("Unlock with your finger, on computers with a reader")
            trailingIcon: "open_in_new"
            onClicked: root.inTerminal(Tr.tr("Add a fingerprint"), `printf '%s\\n\\n' '${Tr.tr("Touch the reader again and again until it says it is done.")}'; fprintd-enroll`)
        }

        RowButton {
            last: true
            icon: "fingerprint_off"
            text: Tr.tr("Remove your fingerprints")
            trailingIcon: "open_in_new"
            onClicked: root.inTerminal(Tr.tr("Remove your fingerprints"), `fprintd-delete "$USER" && echo '${Tr.tr("Done.")}'`)
        }
    }
}
