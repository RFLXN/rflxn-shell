import Quickshell.Services.Notifications
import QtQuick
import "../../../theme"

Rectangle {
    id: root

    property var notification
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property string relativeTime: FeedHubState.formatNotificationTime(notification?.id ?? 0, FeedHubState.timeRevision)

    width: parent?.width ?? 420
    height: content.implicitHeight + 20
    color: critical ? Qt.rgba(Colors.critical.r, Colors.critical.g, Colors.critical.b, 0.22) : Colors.widgetBgHover
    radius: 14

    function dismiss() {
        if (notification)
            notification.dismiss();
    }

    FeedHubNotificationContent {
        id: content

        anchors {
            left: parent.left
            leftMargin: 12
            right: parent.right
            rightMargin: 12
            top: parent.top
            topMargin: 10
        }

        notification: root.notification
        relativeTime: root.relativeTime
        showRelativeTime: true
        onActionInvoked: action => action.invoke()
        onDismissRequested: root.dismiss()
    }
}
