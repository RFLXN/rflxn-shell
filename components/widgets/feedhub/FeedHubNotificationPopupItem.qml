pragma ComponentBehavior: Bound

import Quickshell.Services.Notifications
import QtQuick
import "../../../theme"

Item {
    id: root

    property var notification
    property real maximumHeight: 0
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property real naturalCardHeight: content.implicitHeight + 20
    readonly property real boundedCardHeight: maximumHeight > 0 ? Math.min(naturalCardHeight, Math.max(1, maximumHeight - 8)) : naturalCardHeight

    signal actionInvoked(int notificationId, var action)
    signal dismissRequested(int notificationId)

    implicitWidth: 392
    implicitHeight: card.height + 8
    width: parent?.width ?? implicitWidth
    height: implicitHeight

    Rectangle {
        id: shadow

        x: 0
        y: 6
        width: card.width
        height: card.height
        color: "#000000"
        opacity: 0.36
        radius: card.radius
    }

    Rectangle {
        id: card

        width: parent.width
        height: root.boundedCardHeight
        border.color: Colors.widgetBorder
        border.width: 1
        color: root.critical ? Qt.rgba(Colors.critical.r, Colors.critical.g, Colors.critical.b, 0.22) : Colors.widgetBgHover
        radius: 14

        Flickable {
            id: contentViewport

            anchors.fill: parent
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: content.implicitHeight + 20
            contentWidth: width
            interactive: contentHeight > height

            FeedHubNotificationContent {
                id: content

                x: 12
                y: 10
                width: Math.max(0, contentViewport.width - 24)
                imageFallbackHeight: 112
                imageMaximumHeight: 160
                notification: root.notification
                onActionInvoked: action => root.actionInvoked(Number(root.notification?.id ?? -1), action)
                onDismissRequested: root.dismissRequested(Number(root.notification?.id ?? -1))
            }
        }
    }
}
