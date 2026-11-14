pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Wallpaper & style")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        StyledClippingRect {
            id: wallWrapper

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: {
                const screen = root.nState.screen;
                return implicitHeight / screen.height * screen.width;
            }
            implicitHeight: {
                const screen = root.nState.screen;
                const cWidth = root.cappedWidth;
                return Math.min(Math.round(cWidth * 0.4), cWidth / screen.width * screen.height);
            }

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            Loader {
                anchors.centerIn: parent
                opacity: Config.background.wallpaperEnabled ? 0 : 1
                active: opacity > 0

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("Wallpaper disabled")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.large
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }

            Item {
                anchors.fill: parent
                opacity: Config.background.wallpaperEnabled ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                Loader {
                    id: wallIndicatorLoader

                    anchors.centerIn: parent

                    opacity: 0
                    active: opacity > 0

                    sourceComponent: StyledRect {
                        implicitWidth: wallLoadingIndicator.implicitSize + Tokens.padding.largeIncreased * 2
                        implicitHeight: wallLoadingIndicator.implicitSize + Tokens.padding.largeIncreased * 2

                        color: Colours.palette.m3primaryContainer
                        radius: Tokens.rounding.full

                        LoadingIndicator {
                            id: wallLoadingIndicator

                            anchors.centerIn: parent
                            containsIcon: true
                            implicitSize: Math.min(wallWrapper.implicitWidth, wallWrapper.implicitHeight) * 0.4
                        }
                    }

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                Timer {
                    id: wallLoadDebounceTimer

                    interval: 100
                    onTriggered: {
                        if (wallImg.status !== Image.Ready)
                            wallIndicatorLoader.opacity = 1;
                    }
                }

                FadeImage {
                    id: wallImg

                    anchors.fill: parent
                    source: Wallpapers.current
                    preventInit: wallIndicatorLoader.opacity > 0
                    fadeOutAnim: Anim.DefaultEffects
                    fadeInAnim: Anim.SlowEffects

                    onSourceChanged: wallLoadDebounceTimer.restart()

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            wallLoadDebounceTimer.stop();
                            wallIndicatorLoader.opacity = 0;
                        }
                    }
                }
            }
        }

        ButtonRow {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "wallpaper"
                text: Tr.tr("Wallpapers")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                disabled: !Config.background.wallpaperEnabled
                onClicked: root.nState.openSubPage(1) // Wallpaper page
            }

            IconTextButton {
                icon: "palette"
                text: Tr.tr("Colours")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.nState.openSubPage(3) // Colours page
            }
        }

        ToggleRow {
            first: true
            text: Tr.tr("Display wallpaper")
            checked: Config.background.wallpaperEnabled
            onToggled: GlobalConfig.background.wallpaperEnabled = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            text: Tr.tr("Transparency")
            // TRANSLATORS: %1/%2 = opacity values from 0 to 1 for the base surface and layered surfaces
            subtext: Tr.tr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            text: Tr.tr("Dark theme")
            subtext: DesktopSettings.theme.auto !== "off" ? Tr.tr("Switches by itself at the times below") : ""
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
        }

        // Light by day, dark by night (DesktopSettings switches it)
        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            last: DesktopSettings.theme.auto !== "custom"
            label: Tr.tr("Light and dark by the time of day")
            subtext: DesktopSettings.theme.auto === "sun" ? Tr.tr("Light from %1, dark from %2 today").arg(DesktopSettings.sunrise).arg(DesktopSettings.sunset) : Tr.tr("Light by day, dark by night")
            menuItems: [autoOff, autoSun, autoCustom]
            active: menuItems.find(i => i.value === DesktopSettings.theme.auto) ?? autoOff
            onSelected: item => {
                DesktopSettings.theme.auto = item.value;
                DesktopSettings.applyScheduledMode();
            }

            MenuItem {
                id: autoOff

                text: Tr.tr("Off")
                value: "off"
            }
            MenuItem {
                id: autoSun

                text: Tr.tr("Sunrise and sunset")
                value: "sun"
            }
            MenuItem {
                id: autoCustom

                text: Tr.tr("Set times")
                value: "custom"
            }
        }

        TextFieldRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            visible: DesktopSettings.theme.auto === "custom"
            smallField: true
            label: Tr.tr("Light from")
            subtext: Tr.tr("24-hour time, like 07:00")
            value: DesktopSettings.theme.lightFrom
            onEditingFinished: v => {
                if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(v)) {
                    DesktopSettings.theme.lightFrom = v;
                    DesktopSettings.applyScheduledMode();
                }
            }
        }

        TextFieldRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            visible: DesktopSettings.theme.auto === "custom"
            last: true
            smallField: true
            label: Tr.tr("Dark from")
            subtext: Tr.tr("24-hour time, like 19:00")
            value: DesktopSettings.theme.darkFrom
            onEditingFinished: v => {
                if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(v)) {
                    DesktopSettings.theme.darkFrom = v;
                    DesktopSettings.applyScheduledMode();
                }
            }
        }
    }
}
