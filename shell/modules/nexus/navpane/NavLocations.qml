pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus

VerticalFadeFlickable {
    id: root

    required property NexusState nState
    // What's typed in the search box: the list then shows only the pages that match, with the
    // settings on them that do.
    property string query

    readonly property bool searching: query.trim().length > 0
    readonly property var entries: {
        const pages = PageRegistry.pages.map((page, idx) => ({
                    page,
                    idx,
                    hits: [],
                    rank: 0
                }));
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w);
        if (words.length === 0)
            return pages;

        const results = [];
        for (const e of pages) {
            const p = e.page;
            const title = `${p.label} ${p.description}`.toLowerCase();
            const names = p.settings.map(n => n.toLowerCase());
            const all = `${title} ${names.join(" ")} ${p.keywords}`.toLowerCase();
            if (!words.every(w => all.includes(w)))
                continue;
            e.hits = p.settings.filter((n, i) => words.some(w => names[i].includes(w)));
            // Pages named for it first, then those with a setting by that name.
            e.rank = words.every(w => p.label.toLowerCase().includes(w)) ? 0 : e.hits.length > 0 ? 1 : words.some(w => title.includes(w)) ? 2 : 3;
            results.push(e);
        }
        return results.sort((a, b) => a.rank - b.rank || a.idx - b.idx);
    }

    // Enter in the search box opens the first match.
    function openFirst(): void {
        if (entries.length > 0)
            nState.currentPageIdx = entries[0].idx;
    }

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight

    TapHandler {
        onTapped: root.focus = true
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.padding.large
            visible: root.searching && root.entries.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.tr("No settings match “%1”").arg(root.query.trim())
            color: Colours.palette.m3outline
            font: Tokens.font.body.medium
        }

        Repeater {
            id: list

            model: root.entries

            StyledRect {
                id: item

                required property var modelData
                required property int index

                readonly property var page: modelData.page
                readonly property bool isCurrentPage: modelData.idx === root.nState.currentPageIdx
                // While searching, the matches are one group.
                readonly property bool isCategoryStart: index === 0 || (!root.searching && root.entries[index - 1].page.category !== page.category)
                readonly property bool isCategoryEnd: index === list.count - 1 || (!root.searching && root.entries[index + 1].page.category !== page.category)

                Layout.fillWidth: true
                Layout.topMargin: index !== 0 && isCategoryStart ? Tokens.spacing.medium : 0
                implicitHeight: {
                    const h = layout.implicitHeight + layout.anchors.margins * 2;
                    return h % 2 === 0 ? h : h + 1;
                }

                color: isCurrentPage ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                RadiusBehavior on topLeftRadius {}
                RadiusBehavior on topRightRadius {}
                RadiusBehavior on bottomLeftRadius {}
                RadiusBehavior on bottomRightRadius {}

                StateLayer {
                    id: stateLayer

                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius

                    onClicked: root.nState.currentPageIdx = item.modelData.idx
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.fillHeight: true
                        Layout.topMargin: -1
                        Layout.bottomMargin: -1
                        implicitWidth: height

                        radius: Tokens.rounding.full
                        color: item.isCurrentPage ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1

                            text: item.page.icon
                            color: item.isCurrentPage ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                            grade: 25
                            fill: item.page.noFill ? 0 : 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: item.page.label
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.hits.length > 0 ? item.modelData.hits.join(" · ") : item.page.description
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
