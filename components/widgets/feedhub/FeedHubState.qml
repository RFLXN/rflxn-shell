pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property int revision: 0
    property var receivedAtById: ({})
    readonly property var notifications: sortedNotifications(revision)
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

        bumpRevision();
    }

    function formatNotificationTime(notificationId) {
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

    function notificationSortTime(notification) {
        const id = String(notification?.id ?? "");

        return Number(receivedAtById[id] ?? 0);
    }

    function sortedNotifications(_revision) {
        const values = notificationServer.trackedNotifications.values ?? [];
        const next = [];

        for (const notification of values) {
            if (!notification)
                continue;

            markReceived(notification);
            next.push(notification);
        }

        next.sort((left, right) => notificationSortTime(right) - notificationSortTime(left) || Number(right.id) - Number(left.id));

        return next;
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: true
        bodyMarkupSupported: false
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            root.markReceived(notification);
            notification.tracked = true;
            root.bumpRevision();
            root.notificationReceived(notification);
        }
    }

    Connections {
        target: notificationServer.trackedNotifications

        function onValuesChanged() {
            root.bumpRevision();
        }
    }
}
