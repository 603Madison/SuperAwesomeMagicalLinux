pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

// SuperAwesomeMagicalLinux's updates. The system downloads a new version by itself each night and
// it takes over at the next restart, with the version before kept to go back to; this page shows
// where that's at and does it now on request (superawesomemagical-update, bootc rollback).
PageBase {
    id: root

    // From rpm-ostree: "" until read, then "ready" (one is downloaded and waiting for a restart),
    // "current" or "unknown".
    property string updateState
    property string bootedVersion
    property real bootedTime
    property string stagedVersion

    // Runs a script in a terminal that stays open until Enter, for commands that ask for the
    // password (sudo) or a confirmation.
    function inTerminal(title: string, script: string): void {
        Quickshell.execDetached(["foot", "--title", title, "sh", "-c", `${script}; echo; read -rp '${Tr.tr("Press Enter to close.")} ' _`]);
    }

    title: Tr.tr("Updates")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: status

            running: true
            command: ["rpm-ostree", "status", "--json"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let data;
                    try {
                        data = JSON.parse(text);
                    } catch (e) {
                        root.updateState = "unknown";
                        return;
                    }
                    const deployments = data.deployments ?? [];
                    const booted = deployments.find(d => d.booted);
                    const staged = deployments.find(d => d.staged);
                    root.bootedVersion = booted?.version ?? "";
                    root.bootedTime = booted?.timestamp ?? 0;
                    root.stagedVersion = staged?.version ?? "";
                    root.updateState = staged ? "ready" : booted ? "current" : "unknown";
                }
            }
            onExited: code => {
                if (code !== 0)
                    root.updateState = "unknown";
            }
        }

        // Look again now and then while the page is open (the nightly download may land meanwhile).
        Timer {
            running: true
            repeat: true
            interval: 60000
            onTriggered: status.running = true
        }

        // Where things stand
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: hero.implicitHeight + Tokens.padding.extraLarge * 2

            RowLayout {
                id: hero

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.large

                StyledRect {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: heroIcon.implicitHeight + Tokens.padding.large * 2
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: root.updateState === "ready" ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        id: heroIcon

                        anchors.centerIn: parent
                        text: root.updateState === "ready" ? "restart_alt" : root.updateState === "current" ? "verified" : "update"
                        color: root.updateState === "ready" ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.large
                        fill: 1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: root.updateState === "ready" ? Tr.tr("Update ready") : root.updateState === "current" ? Tr.tr("You’re up to date") : Tr.tr("Updates")
                        font: Tokens.font.headline.builders.small.weight(Font.Bold).build()
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (root.updateState === "ready")
                                return Tr.tr("Version %1 is downloaded. Restart to start using it.").arg(root.stagedVersion || "…");
                            if (root.updateState === "current")
                                return Tr.tr("New versions download by themselves each night and take over when you restart.");
                            if (root.updateState === "unknown")
                                return Tr.tr("Couldn’t read the update status just now.");
                            return "…";
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // This computer
        SectionHeader {
            text: Tr.tr("This computer")
        }

        InfoRow {
            first: true
            label: Tr.tr("Installed version")
            value: root.bootedVersion || "…"
        }

        InfoRow {
            label: Tr.tr("Released")
            value: root.bootedTime > 0 ? Qt.locale().toString(new Date(root.bootedTime * 1000), Qt.locale().dateFormat(Locale.LongFormat)) : "…"
        }

        InfoRow {
            last: true
            label: Tr.tr("Automatic updates")
            value: Tr.tr("Every night")
        }

        // Do it now
        SectionHeader {
            text: Tr.tr("Now")
        }

        RowButton {
            visible: root.updateState === "ready"
            first: true
            icon: "restart_alt"
            text: Tr.tr("Restart to update")
            subtext: Tr.tr("Save your work first")
            onClicked: Quickshell.execDetached(["systemctl", "reboot"])
        }

        RowButton {
            first: root.updateState !== "ready"
            icon: "system_update_alt"
            text: Tr.tr("Check for updates now")
            subtext: Tr.tr("Downloads the newest version in a terminal, which asks for your password")
            trailingIcon: "open_in_new"
            onClicked: root.inTerminal(Tr.tr("Update SuperAwesomeMagicalLinux"), "superawesomemagical-update")
        }

        RowButton {
            last: true
            icon: "history"
            text: Tr.tr("Go back to the previous version")
            subtext: Tr.tr("If an update causes trouble. Takes effect when you restart")
            trailingIcon: "open_in_new"
            onClicked: root.inTerminal(Tr.tr("Previous version"), "printf '%s\\n' '" + Tr.tr("This goes back to the version you used before the last update, from your next restart. Your files and settings stay as they are.") + "'; printf '%s ' '" + Tr.tr("Go back? [y/N]") + "'; read a; case $a in [yY]*) sudo bootc rollback && echo '" + Tr.tr("Done. Restart to use it.") + "';; esac")
        }

        // Apps
        SectionHeader {
            text: Tr.tr("Apps")
        }

        InfoRow {
            first: true
            last: true
            label: Tr.tr("Apps from Software (Flathub)")
            value: Tr.tr("Update by themselves daily")
        }
    }
}
