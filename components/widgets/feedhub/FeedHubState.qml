pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property int revision: 0
    property int timeRevision: 0
    property var receivedAtById: ({})
    property var notificationList: []
    readonly property var notifications: notificationList
    readonly property int notificationCount: notifications.length
    readonly property bool hasNotifications: notificationCount > 0

    signal notificationReceived(var notification)

    function bumpRevision() {
        revision += 1;
    }

    function dismissAllNotifications() {
        const current = notifications.slice();

        for (const notification of current)
            notification.dismiss();
    }

    function formatNotificationTime(notificationId, _timeRevision) {
        const timestamp = Number(receivedAtById[String(notificationId)] ?? Date.now());
        const elapsedSeconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000));

        if (elapsedSeconds < 60)
            return `${elapsedSeconds} second${elapsedSeconds === 1 ? "" : "s"} ago`;

        if (elapsedSeconds < 3600) {
            const minutes = Math.floor(elapsedSeconds / 60);

            return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;
        }

        if (elapsedSeconds <= 10800) {
            const hours = Math.floor(elapsedSeconds / 3600);

            return `${hours} hour${hours === 1 ? "" : "s"} ago`;
        }

        return Qt.formatDateTime(new Date(timestamp), "yyyy-MM-dd HH:mm");
    }

    function markReceived(notification) {
        const id = String(notification?.id ?? "");

        if (!id)
            return;

        if (receivedAtById[id] !== undefined)
            return;

        const next = Object.assign({}, receivedAtById);

        next[id] = Date.now();
        receivedAtById = next;
    }

    function syncNotifications() {
        const values = notificationServer.trackedNotifications.values ?? [];
        const nextReceivedAtById = {};
        const next = [];
        const now = Date.now();

        for (const notification of values) {
            if (!notification)
                continue;

            const id = String(notification.id);
            const receivedAt = Number(receivedAtById[id] ?? now);

            nextReceivedAtById[id] = receivedAt;
            next.push(notification);
        }

        next.sort((left, right) => {
            const leftTime = Number(nextReceivedAtById[String(left.id)] ?? 0);
            const rightTime = Number(nextReceivedAtById[String(right.id)] ?? 0);

            return rightTime - leftTime || Number(right.id) - Number(left.id);
        });

        receivedAtById = nextReceivedAtById;
        notificationList = next;
        bumpRevision();
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        bodyMarkupSupported: false
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            root.markReceived(notification);
            notification.tracked = true;
            root.syncNotifications();
            root.notificationReceived(notification);
        }
    }

    Connections {
        target: notificationServer.trackedNotifications

        function onValuesChanged() {
            root.syncNotifications();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.hasNotifications
        triggeredOnStart: true
        onTriggered: root.timeRevision += 1
    }

    Component.onCompleted: root.syncNotifications()
}
