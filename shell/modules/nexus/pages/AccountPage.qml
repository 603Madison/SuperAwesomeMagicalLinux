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
import qs.modules.nexus
import qs.modules.nexus.common

// Your account: your picture (~/.face, which the sign-in and lock screens and the dashboard show),
// your password, and fingerprints for unlocking (fprintd). The ones that ask for your password run
// in a terminal. Below them, the SuperAwesomeMagical account: signing this computer in to a
// SuperAwesomeMagicalOrchestrator (services/Orchestrator.qml), which signs the family's apps in and
// joins this computer to the person's devices (the Your devices page).
PageBase {
    id: root

    property string fullName
    readonly property string userName: Quickshell.env("USER")
    // The orchestrator's address as typed, until it's sent.
    property string serverAddress: Orchestrator.server

    function signIn(): void {
        Orchestrator.signIn(serverAddress);
    }

    function openDevices(): void {
        nState.currentPageIdx = PageRegistry.pages.findIndex(p => p.id === "yourdevices");
    }

    // Runs a script in a terminal that stays open until Enter.
    function inTerminal(title: string, script: string): void {
        Quickshell.execDetached(["foot", "--title", title, "sh", "-c", `${script}; echo; read -rp '${Tr.tr("Press Enter to close.")} ' _`]);
    }

    title: Tr.tr("Your account")

    Component.onCompleted: Orchestrator.refs++
    Component.onDestruction: Orchestrator.refs--

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

        // The SuperAwesomeMagical account: one sign-in for the family's apps and your devices.
        SectionHeader {
            text: Tr.tr("SuperAwesomeMagical account")
        }

        // Not in this build, or not answering.
        InfoRow {
            visible: !Orchestrator.available || !Orchestrator.loaded
            first: true
            last: true
            icon: Orchestrator.installed === "no" || Orchestrator.unreachable ? "cloud_off" : "hourglass_empty"
            label: Tr.tr("One sign-in for your apps and devices")
            subtext: Orchestrator.installed === "no" ? Tr.tr("Not part of this version yet. It arrives with an update.") : Orchestrator.unreachable ? Tr.tr("Couldn’t reach it just now.") : "…"
        }

        // Signed out: where to sign in.
        TextFieldRow {
            visible: Orchestrator.loaded && !Orchestrator.signedIn && !Orchestrator.signingIn
            first: true
            label: Tr.tr("Server")
            subtext: Tr.tr("Your orchestrator’s address")
            placeholderText: Tr.tr("Address")
            field.Layout.preferredWidth: root.cappedWidth / 2
            value: root.serverAddress
            field.inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
            onValueEdited: value => root.serverAddress = value
            field.onAccepted: root.signIn()
        }

        RowButton {
            visible: Orchestrator.loaded && !Orchestrator.signedIn && !Orchestrator.signingIn
            last: !problem.visible
            icon: "login"
            text: Tr.tr("Sign in")
            subtext: /^http:\/\//i.test(root.serverAddress.trim()) ? Tr.tr("This address isn’t https: only use it on a network you trust") : Tr.tr("Opens your browser. Music, Email and the rest then sign in by themselves")
            trailingIcon: "open_in_new"
            disabled: root.serverAddress.trim() === ""
            onClicked: root.signIn()
        }

        // Why it didn't work, in the agent's words (all of them: they say what to do).
        ConnectedRect {
            id: problem

            readonly property string words: Orchestrator.signInError || Orchestrator.actionError

            Layout.fillWidth: true
            visible: Orchestrator.loaded && !Orchestrator.signedIn && !Orchestrator.signingIn && words !== ""
            last: true
            implicitHeight: problemLayout.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: problemLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "error"
                    color: Colours.palette.m3error
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("The sign-in didn’t work")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: problem.words
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // Signing in: the code to compare with the page in the browser.
        ConnectedRect {
            Layout.fillWidth: true
            visible: Orchestrator.loaded && Orchestrator.signingIn
            first: true
            implicitHeight: pairing.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: pairing

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Your code")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Orchestrator.pairingCode || "…"
                    color: Colours.palette.m3primary
                    font: Tokens.font.headline.builders.medium.weight(Font.Bold).scale(1.6).build()
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("The sign-in page shows the same code. Only carry on there if they match.")
                    font: Tokens.font.body.medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Waiting for you to sign in in your browser…")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowButton {
            visible: Orchestrator.loaded && Orchestrator.signingIn
            last: true
            icon: "open_in_browser"
            text: Tr.tr("Open the sign-in page again")
            subtext: Orchestrator.server
            trailingIcon: "open_in_new"
            disabled: !Orchestrator.mayOpen(Orchestrator.signInUrl)
            onClicked: Orchestrator.open(Orchestrator.signInUrl)
        }

        // Signed in: who and where.
        InfoRow {
            visible: Orchestrator.loaded && Orchestrator.signedIn
            first: true
            icon: Orchestrator.connected ? "verified_user" : "cloud_off"
            iconColour: Orchestrator.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            label: Tr.tr("Signed in as %1").arg(Orchestrator.displayName)
            subtext: Orchestrator.server
            value: Orchestrator.connected ? Tr.tr("Connected") : Tr.tr("Not connected right now")
        }

        NavRow {
            visible: Orchestrator.loaded && Orchestrator.signedIn
            icon: "devices"
            text: Tr.tr("Your devices")
            subtext: Tr.tr("This computer is “%1”").arg(Orchestrator.deviceName)
            onClicked: root.openDevices()
        }

        RowButton {
            visible: Orchestrator.loaded && Orchestrator.signedIn
            last: true
            icon: "logout"
            text: Tr.tr("Sign out")
            subtext: Tr.tr("Takes this computer off your devices")
            onClicked: Orchestrator.signOut()
        }
    }
}
