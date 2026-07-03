import Quickshell.Hyprland
import QtQuick
import "../../../theme"
import "../../state"

Rectangle {
    id: root

    property int horizontalPadding: 10
    property int indicatorSpacing: Metrics.globalYSpacing * 2
    property int indicatorVerticalMargin: Metrics.globalYSpacing
    property string menuId: "system-controls"
    property var screen
    readonly property bool active: GlobalMenu.isMenuOpen(menuId, screenName)
    readonly property bool hovered: controlArea.containsMouse
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property string detectedScreenName: monitor?.name ?? ""
    property string screenName: detectedScreenName

    width: content.implicitWidth + horizontalPadding * 2
    height: Metrics.widgetHeight
    border.color: hovered || active ? Colors.widgetBorder : "transparent"
    border.width: 1
    color: hovered || active ? Colors.widgetBgActive : "transparent"
    radius: height / 2

    Behavior on color {
        ColorAnimation {
            duration: 160
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 160
            easing.type: Easing.InOutQuad
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.indicatorSpacing

        Item {
            readonly property int wrappedHeight: volume.implicitHeight + root.indicatorVerticalMargin * 2

            width: volume.implicitWidth
            height: wrappedHeight
            implicitWidth: volume.implicitWidth
            implicitHeight: wrappedHeight

            VolumeIndicator {
                id: volume

                anchors.centerIn: parent
                active: root.active
            }
        }

        Item {
            readonly property int wrappedHeight: battery.implicitHeight + root.indicatorVerticalMargin * 2

            visible: battery.available
            width: battery.available ? battery.implicitWidth : 0
            height: battery.available ? wrappedHeight : 0
            implicitWidth: width
            implicitHeight: height

            BatteryIndicator {
                id: battery

                anchors.centerIn: parent
                active: root.active
            }
        }

        Item {
            visible: bluetooth.available
            width: bluetooth.available ? bluetooth.implicitWidth : 0
            height: bluetooth.available ? bluetooth.implicitHeight : 0
            implicitWidth: width
            implicitHeight: height

            BluetoothIndicator {
                id: bluetooth

                anchors.centerIn: parent
                active: root.active
            }
        }

        Item {
            width: network.implicitWidth
            height: network.implicitHeight
            implicitWidth: network.implicitWidth
            implicitHeight: network.implicitHeight

            NetworkIndicator {
                id: network

                anchors.centerIn: parent
                active: root.active
            }
        }
    }

    MouseArea {
        id: controlArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: GlobalMenu.toggleMenu(root.menuId, root.screenName)
    }
}
