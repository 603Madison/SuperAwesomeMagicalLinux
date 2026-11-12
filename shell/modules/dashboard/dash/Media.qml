pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import qs.utils

Item {
    id: root

    property real playerProgress: {
        const active = Players.active;
        return active?.length ? (active.position % active.length) / active.length : 0;
    }

    readonly property real arcCoverGap: Tokens.spacing.extraSmall

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Tokens.sizes.dashboard.mediaWidth

    Behavior on playerProgress {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Timer {
        running: Players.active?.isPlaying ?? false
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: Players.active?.positionChanged()
    }

    CircularProgress {
        id: prog

        anchors.centerIn: cover
        implicitSize: cover.width + root.arcCoverGap + thickness * 2

        fgColour: Colours.palette.m3primary
        strokeWidth: Tokens.sizes.dashboard.mediaProgressThickness
        startAngle: -90 - sweepAngle / 2
        sweepAngle: Tokens.sizes.dashboard.mediaProgressSweep
        value: root.playerProgress

        wavy: true
        waveFrequency: 8
        waveDuration: 2000
        wavePaused: !Players.active?.isPlaying
    }

    CoverArt {
        id: cover

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.medium + root.arcCoverGap + prog.thickness
        implicitHeight: width
    }

    StyledText {
        id: title

        anchors.top: cover.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.spacing.medium

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: (Players.active?.trackTitle ?? Tr.tr("Nothing playing")) || Tr.tr("Unknown title")
        color: Colours.palette.m3primary
        font: Tokens.font.title.builders.small.weight(Font.Bold).build()

        width: parent.implicitWidth - Tokens.padding.extraLargeIncreased
        elide: Text.ElideRight
    }

    StyledText {
        id: album

        anchors.top: title.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.spacing.small

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: (Players.active?.trackAlbum ?? Tr.tr("Your music shows up here")) || Tr.tr("Unknown album")
        color: Colours.palette.m3outline
        font: Tokens.font.body.small

        width: parent.implicitWidth - Tokens.padding.extraLargeIncreased
        elide: Text.ElideRight
    }

    StyledText {
        id: artist

        anchors.top: album.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.spacing.small

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: (Players.active?.trackArtist ?? "") || Tr.tr("Unknown artist")
        color: Colours.palette.m3secondary

        width: parent.implicitWidth - Tokens.padding.extraLargeIncreased
        elide: Text.ElideRight
    }

    ButtonRow {
        id: controls

        anchors.top: artist.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.spacing.medium
        anchors.margins: Tokens.padding.large

        spacing: Tokens.spacing.extraSmall

        IconButton {
            type: IconButton.Tonal
            icon: "skip_previous"
            isRound: true
            shapeMorph: true
            disabled: !Players.active?.canGoPrevious
            onClicked: Players.active?.previous()
        }

        IconButton {
            fillWidth: true
            icon: Players.active?.isPlaying ? "pause" : "play_arrow"
            isRound: true
            shapeMorph: true
            checked: Players.active?.isPlaying ?? false
            disabled: !Players.active?.canTogglePlaying
            onClicked: Players.active?.togglePlaying()
        }

        IconButton {
            type: IconButton.Tonal
            icon: "skip_next"
            isRound: true
            shapeMorph: true
            disabled: !Players.active?.canGoNext
            onClicked: Players.active?.next()
        }
    }

    // Aurora bars: the music as a little aurora, purple fading into green. At rest they settle
    // into a row of dots.
    Item {
        id: aurora

        readonly property int barCount: 16
        readonly property real gap: Tokens.spacing.extraSmall
        readonly property list<real> levels: {
            const v = Audio.cava.values;
            const n = v?.length ?? 0;
            const out = [];
            for (let i = 0; i < barCount; i++) {
                if (!n) {
                    out.push(0);
                    continue;
                }
                // Average the visualiser's bars that fall into this one.
                const a = Math.floor(i * n / barCount);
                const b = Math.max(a + 1, Math.floor((i + 1) * n / barCount));
                let sum = 0;
                for (let j = a; j < b; j++)
                    sum += v[j];
                out.push(sum / (b - a));
            }
            return out;
        }

        anchors.top: controls.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.spacing.large
        anchors.bottomMargin: Tokens.padding.large
        anchors.leftMargin: Tokens.padding.extraLargeIncreased
        anchors.rightMargin: Tokens.padding.extraLargeIncreased

        opacity: Players.active?.isPlaying ? 1 : 0.45

        Behavior on opacity {
            Anim {}
        }

        ServiceRef {
            service: Audio.cava
        }

        Repeater {
            model: aurora.barCount

            Rectangle {
                id: bar

                required property int index

                width: (aurora.width - aurora.gap * (aurora.barCount - 1)) / aurora.barCount
                height: Math.max(width, aurora.height * Math.min(1, aurora.levels[index] ?? 0))
                x: index * (width + aurora.gap)
                y: aurora.height - height
                radius: width / 2

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Colours.palette.m3primary
                    }
                    GradientStop {
                        position: 1
                        color: Colours.palette.m3secondary
                    }
                }

                Behavior on height {
                    Anim {
                        type: Anim.StandardSmall
                    }
                }
            }
        }
    }
}
