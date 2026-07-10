pragma ComponentBehavior: Bound

import Quickshell.Services.SystemTray
import QtQuick
import "../../../theme"
import "../../menu"

SideMenu {
    id: root

    contentPadding: 5
    cornerRadius: 23
    direction: "left"
    menuId: "feed-hub"
    menuMargin: 6
    menuTopOffset: 0
    menuWidth: 450

    onMenuOpenChanged: {
        if (!menuOpen)
            trayContextMenu.closeMenu();
    }

    Column {
        anchors.fill: parent
        spacing: 0

        Flickable {
            id: trayFlickable

            width: parent.width
            height: 30
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: height
            contentWidth: Math.max(width, trayRow.implicitWidth + 16)

            Row {
                id: trayRow

                anchors.verticalCenter: parent.verticalCenter
                x: 8
                spacing: 4

                Repeater {
                    model: root.mounted ? SystemTray.items.values : []

                    FeedHubTrayItem {
                        required property var modelData

                        menuPresenter: trayContextMenu
                        trayItem: modelData
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.separator
        }

        Item {
            width: parent.width
            height: FeedHubState.hasNotifications ? 42 : 0
            visible: FeedHubState.hasNotifications

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    right: parent.right
                    rightMargin: 8
                    top: parent.top
                    topMargin: 8
                }

                height: 26
                border.color: dismissArea.containsMouse ? Colors.critical : Colors.widgetBorder
                border.width: 1
                color: dismissArea.containsMouse ? Colors.critical : Colors.widgetBgHover
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    color: dismissArea.containsMouse ? Colors.textPrimary : Colors.textSecondary
                    font.family: Typography.textFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    text: "Dismiss All"
                }

                MouseArea {
                    id: dismissArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: FeedHubState.dismissAllNotifications()
                }
            }
        }

        ListView {
            id: notificationList

            x: 8
            width: Math.max(0, parent.width - 16)
            height: Math.max(0, parent.height - trayFlickable.height - 1 - (FeedHubState.hasNotifications ? 42 : 0))
            boundsBehavior: Flickable.StopAtBounds
            bottomMargin: 8
            cacheBuffer: 64
            clip: true
            model: root.mounted ? FeedHubState.notifications : []
            spacing: 6
            topMargin: 8
            visible: FeedHubState.hasNotifications

            delegate: FeedHubNotificationItem {
                required property var modelData

                width: ListView.view.width
                notification: modelData
            }
        }

        Item {
            width: parent.width
            height: Math.max(0, parent.height - trayFlickable.height - 1)
            visible: !FeedHubState.hasNotifications

            Text {
                anchors.centerIn: parent
                color: Colors.textMuted
                font.family: Typography.textFamily
                font.pixelSize: 13
                font.weight: Font.Bold
                text: "No notifications"
            }
        }
    }

    FeedHubTrayContextMenu {
        id: trayContextMenu

        parent: root.overlayContainer
        anchors.fill: parent
        z: 10
    }
}
