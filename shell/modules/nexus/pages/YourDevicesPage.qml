pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Your devices: the phones and computers signed in to the same SuperAwesomeMagical account as this
// one (services/Orchestrator.qml asks the agent). Ring one, send it the clipboard, carry on with
// what another is doing, open the family's apps, and choose what this computer shares. Signing in
// and out is on the Your account page.
PageBase {
    id: root

    readonly property bool ready: Orchestrator.loaded && Orchestrator.signedIn

    function openAccount(): void {
        nState.currentPageIdx = PageRegistry.pages.findIndex(p => p.id === "account");
    }

    function kindIcon(kind: string): string {
        return kind === "LINUX" ? "computer" : kind === "ANDROID" ? "smartphone" : "devices";
    }

    function appIcon(app: string): string {
        return ({
                music: "music_note",
                video: "smart_display",
                email: "mail",
                maps: "map",
                health: "favorite",
                browser: "public"
            })[app] ?? "apps";
    }

    function can(device: var, what: string): bool {
        const list = device.capabilities ?? [];
        return list.length === 0 || list.includes(what);
    }

    // "5 minutes ago", from a time in milliseconds.
    function ago(at: real): string {
        const minutes = Math.floor((Date.now() - at) / 60000);
        if (!(at > 0))
            return "";
        if (minutes < 1)
            return Tr.tr("just now");
        if (minutes < 60)
            return minutes === 1 ? Tr.tr("a minute ago") : Tr.tr("%1 minutes ago").arg(minutes);
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours === 1 ? Tr.tr("an hour ago") : Tr.tr("%1 hours ago").arg(hours);
        const days = Math.floor(hours / 24);
        return days === 1 ? Tr.tr("yesterday") : Tr.tr("%1 days ago").arg(days);
    }

    function deviceLine(device: var): string {
        const parts = [];
        if (device.current)
            parts.push(Tr.tr("This computer"));
        if (device.online)
            parts.push(Tr.tr("Connected"));
        else if (device.lastSeenAt > 0)
            parts.push(Tr.tr("Last seen %1").arg(ago(device.lastSeenAt)));
        else
            parts.push(Tr.tr("Away"));
        if (device.battery)
            parts.push(device.battery.charging ? Tr.tr("%1% and charging").arg(device.battery.level) : Tr.tr("%1%").arg(device.battery.level));
        return parts.join(" · ");
    }

    function host(url: string): string {
        return url.replace(/^[a-z]+:\/\//i, "").replace(/\/.*$/, "");
    }

    title: Tr.tr("Your devices")

    Component.onCompleted: Orchestrator.refs++
    Component.onDestruction: Orchestrator.refs--

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Not signed in (or the agent isn't in this version): where to go.
        ConnectedRect {
            Layout.fillWidth: true
            visible: !root.ready
            first: true
            implicitHeight: welcome.implicitHeight + Tokens.padding.extraLarge * 2

            RowLayout {
                id: welcome

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.large

                StyledRect {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: welcomeIcon.implicitHeight + Tokens.padding.large * 2
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        id: welcomeIcon

                        anchors.centerIn: parent
                        text: "devices"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.large
                        fill: 1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Your phone and computers, together")
                        font: Tokens.font.headline.builders.small.weight(Font.Bold).build()
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Orchestrator.installed === "no" ? Tr.tr("Not part of this version yet. It arrives with an update.") : Tr.tr("Sign in once and your devices share notifications, the clipboard and links, ring each other, and carry on where another left off.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        NavRow {
            visible: !root.ready
            last: true
            icon: "login"
            text: Orchestrator.signingIn ? Tr.tr("Finish signing in") : Tr.tr("Sign in")
            subtext: Tr.tr("In Your account")
            disabled: !Orchestrator.available
            onClicked: root.openAccount()
        }

        // Something asked for here didn't work: the agent's own words.
        InfoRow {
            visible: root.ready && Orchestrator.actionError !== ""
            Layout.bottomMargin: Tokens.spacing.large - parent.spacing
            first: true
            last: true
            icon: "error"
            iconColour: Colours.palette.m3error
            label: Orchestrator.actionError
        }

        // Carry on: what's happening on the other devices.
        SectionHeader {
            visible: root.ready && Orchestrator.activities.length > 0
            first: true
            text: Tr.tr("Carry on")
        }

        Repeater {
            model: root.ready ? Orchestrator.activities : []

            RowButton {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Orchestrator.activities.length - 1
                icon: root.appIcon(modelData.app)
                text: modelData.title
                // TRANSLATORS: %1 = an app ("Music"), %2 = a device's name ("Pixel 9")
                subtext: Tr.tr("%1 on %2").arg(Orchestrator.apps.find(a => a.id === modelData.app)?.name ?? modelData.app).arg(modelData.deviceName) + (modelData.detail ? ` · ${modelData.detail}` : "")
                trailingIcon: "open_in_new"
                disabled: !Orchestrator.mayOpen(modelData.url)
                onClicked: Orchestrator.open(modelData.url)
            }
        }

        // The devices
        SectionHeader {
            visible: root.ready
            first: Orchestrator.activities.length === 0
            text: Tr.tr("Devices")
        }

        InfoRow {
            visible: root.ready && Orchestrator.devices.length === 0
            first: true
            last: true
            icon: Orchestrator.connected ? "hourglass_empty" : "cloud_off"
            label: Orchestrator.connected ? "…" : Tr.tr("Not connected right now. It keeps trying.")
        }

        Repeater {
            model: root.ready ? Orchestrator.devices : []

            ConnectedRect {
                id: device

                required property var modelData
                required property int index
                readonly property bool ringing: Orchestrator.isRinging(modelData.id)

                Layout.fillWidth: true
                first: index === 0
                implicitHeight: deviceLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: deviceLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: deviceIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: device.modelData.online ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            id: deviceIcon

                            anchors.centerIn: parent
                            text: root.kindIcon(device.modelData.kind ?? "")
                            color: device.modelData.online ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.medium
                            fill: device.modelData.online ? 1 : 0
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: device.modelData.name + (device.modelData.model && device.modelData.model !== device.modelData.name ? ` · ${device.modelData.model}` : "")
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.deviceLine(device.modelData)
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    IconTextButton {
                        visible: !device.modelData.current && root.can(device.modelData, "clipboard")
                        type: IconTextButton.Text
                        icon: "content_paste_go"
                        text: Tr.tr("Send clipboard")
                        onClicked: Orchestrator.sendClipboard(device.modelData.id)
                    }

                    IconTextButton {
                        visible: !device.modelData.current && root.can(device.modelData, "ring")
                        type: device.ringing ? IconTextButton.Filled : IconTextButton.Tonal
                        icon: device.ringing ? "notifications_off" : "notifications_active"
                        text: device.ringing ? Tr.tr("Stop") : Tr.tr("Ring")
                        onClicked: Orchestrator.ring(device.modelData.id, !device.ringing)
                    }
                }
            }
        }

        // Renaming and removing aren't things the agent does; the orchestrator's own page is.
        RowButton {
            visible: root.ready && Orchestrator.devices.length > 0
            last: true
            icon: "edit"
            text: Tr.tr("Rename or remove a device")
            subtext: Tr.tr("On your account’s page, %1").arg(root.host(Orchestrator.server))
            trailingIcon: "open_in_new"
            disabled: !Orchestrator.mayOpen(Orchestrator.server)
            onClicked: Orchestrator.open(Orchestrator.server)
        }

        // The family's apps this account is signed in to
        SectionHeader {
            visible: root.ready && Orchestrator.apps.length > 0
            text: Tr.tr("Your apps")
        }

        Repeater {
            model: root.ready ? Orchestrator.apps : []

            RowButton {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Orchestrator.apps.length - 1
                icon: root.appIcon(modelData.id)
                text: modelData.name
                subtext: root.host(modelData.url ?? "")
                trailingIcon: "open_in_new"
                disabled: !Orchestrator.mayOpen(modelData.url ?? "")
                onClicked: Orchestrator.open(modelData.url)
            }
        }

        // What this computer shares
        SectionHeader {
            visible: root.ready
            text: Tr.tr("Sharing")
        }

        ToggleRow {
            visible: root.ready
            first: true
            text: Tr.tr("Send notifications to my other devices")
            subtext: Tr.tr("Never from password managers or one-time-code apps")
            checked: Orchestrator.settings.notificationsOut === true
            onToggled: Orchestrator.setSetting("notificationsOut", checked)
        }

        ToggleRow {
            visible: root.ready
            text: Tr.tr("Show my other devices’ notifications here")
            checked: Orchestrator.settings.notificationsIn === true
            onToggled: Orchestrator.setSetting("notificationsIn", checked)
        }

        ToggleRow {
            visible: root.ready
            text: Tr.tr("Accept the clipboard")
            subtext: Tr.tr("When another device sends its clipboard here")
            checked: Orchestrator.settings.clipboard === true
            onToggled: Orchestrator.setSetting("clipboard", checked)
        }

        ToggleRow {
            visible: root.ready
            last: true
            text: Tr.tr("Open links sent here")
            subtext: Tr.tr("In your browser, or in the app they belong to")
            checked: Orchestrator.settings.links === true
            onToggled: Orchestrator.setSetting("links", checked)
        }
    }
}
