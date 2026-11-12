pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// The lock screen's hello: the SuperAwesomeMagical mark, a greeting for the time of day and the
// person's name, and under it the battery on a laptop or which OS this is.
StyledRect {
    id: root

    required property real rootHeight

    readonly property string greeting: {
        const h = Time.hours;
        if (h >= 5 && h < 12)
            return Tr.tr("Good morning,");
        if (h >= 12 && h < 17)
            return Tr.tr("Good afternoon,");
        return Tr.tr("Good evening,");
    }

    readonly property string detail: {
        const dev = UPower.displayDevice;
        if (dev.isLaptopBattery) {
            const pct = Math.round(dev.percentage * 100);
            const charging = [UPowerDeviceState.Charging, UPowerDeviceState.PendingCharge].includes(dev.state);
            if (dev.state === UPowerDeviceState.FullyCharged)
                return Tr.tr("Battery full");
            return charging ? Tr.tr("Battery %1% · charging").arg(pct) : Tr.tr("Battery %1%").arg(pct);
        }
        return SysInfo.osPrettyName || SysInfo.osName;
    }

    implicitHeight: layout.implicitHeight + Tokens.padding.extraLarge * 2
    radius: Tokens.rounding.medium
    color: Colours.tPalette.m3surfaceContainer

    RowLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.extraLarge
        spacing: Tokens.spacing.large

        Logo {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Tokens.sizes.dashboard.logoSize * 2.2
            Layout.preferredHeight: Tokens.sizes.dashboard.logoSize * 2.2
            visible: root.width > Tokens.sizes.lock.largeLogoWidth
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                text: root.greeting
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.builders.small.weight(Font.Medium).build()
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: SysInfo.displayName
                color: Colours.palette.m3primary
                font: Tokens.font.headline.builders.small.weight(Font.Bold).build()
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                text: root.detail
                color: Colours.palette.m3outline
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                elide: Text.ElideRight
            }
        }
    }
}
