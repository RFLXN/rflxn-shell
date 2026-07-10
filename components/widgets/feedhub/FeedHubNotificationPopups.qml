pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../../config"
import "../../../theme"
import "../../state"

PanelWindow {
    id: root

    property int margin: 8
    property int maxVisible: 3
    property int popupWidth: 392
    property int timeoutMs: 6000
    property string position: "top-right"
    property string screenName: ""
    property var expiresAtById: ({})
    property var modelData
    property var popups: []
    readonly property int effectiveMaxVisible: Math.max(1, maxVisible)
    readonly property int effectiveTimeoutMs: Math.max(1, timeoutMs)
    readonly property bool leftPosition: normalizedPosition.endsWith("-left")
    readonly property string normalizedPosition: normalizePosition(position)
    readonly property var orderedPopups: topPosition ? popups : popups.slice().reverse()
    readonly property bool topPosition: normalizedPosition.startsWith("top-")
    readonly property int effectiveScreenHeight: Math.max(1, Number(modelData?.height ?? 1))
    readonly property int effectiveScreenWidth: Math.max(1, Number(modelData?.width ?? 1))
    readonly property int maximumStackHeight: Math.max(1, effectiveScreenHeight - (topPosition ? Metrics.barHeight : 0) - margin * 2)

    screen: modelData

    anchors {
        bottom: !root.topPosition
        left: root.leftPosition
        right: !root.leftPosition
        top: root.topPosition
    }

    margins {
        bottom: root.margin
        left: root.margin
        right: root.margin
        top: root.topPosition ? Metrics.barHeight + root.margin : root.margin
    }

    color: "transparent"
    exclusiveZone: 0
    focusable: false
    implicitHeight: Math.min(popupStack.implicitHeight, maximumStackHeight)
    implicitWidth: Math.max(1, Math.min(popupWidth, effectiveScreenWidth - margin * 2))
    surfaceFormat.opaque: false
    visible: popups.length > 0

    function normalizePosition(value) {
        const text = String(value ?? "");

        if (text === "top-left" || text === "top-right" || text === "bottom-left" || text === "bottom-right")
            return text;

        return "top-right";
    }

    function popupId(notification) {
        return Number(notification?.id ?? -1);
    }

    function targetScreenName() {
        const focusedName = String(Hyprland.focusedMonitor?.name ?? "");

        if (focusedName && Layouts.hasOverlay(Layouts.layoutForScreen(focusedName), "notification-popups"))
            return focusedName;

        const screens = Quickshell.screens ?? [];

        for (let index = 0; index < screens.length; index++) {
            const screen = screens[index];
            const monitorName = String(Hyprland.monitorFor(screen)?.name ?? "");
            const candidateName = monitorName || String(screen?.name ?? "");

            if (candidateName && Layouts.hasOverlay(Layouts.layoutForScreen(candidateName), "notification-popups"))
                return candidateName;
        }

        return "";
    }

    function trimExpires(nextPopups, expires) {
        const visibleIds = {};

        for (const popup of nextPopups)
            visibleIds[String(popup.id)] = true;

        for (const id of Object.keys(expires)) {
            if (!visibleIds[id])
                delete expires[id];
        }
    }

    function setPopupList(nextPopups, nextExpires) {
        trimExpires(nextPopups, nextExpires);
        expiresAtById = nextExpires;
        popups = nextPopups;
    }

    function pushPopup(notification) {
        if (!notification || GlobalMenu.activeMenu === "feed-hub" || screenName !== targetScreenName())
            return;

        const id = popupId(notification);

        if (id < 0)
            return;

        const nextExpires = Object.assign({}, expiresAtById);
        const nextPopups = [{
                id,
                notification
            }].concat(popups.filter(popup => popup.id !== id)).slice(0, effectiveMaxVisible);

        nextExpires[String(id)] = Date.now() + effectiveTimeoutMs;
        setPopupList(nextPopups, nextExpires);
    }

    function clearPopups() {
        expiresAtById = {};
        popups = [];
    }

    function removePopup(id) {
        const numericId = Number(id);
        const nextExpires = Object.assign({}, expiresAtById);
        const nextPopups = popups.filter(popup => popup.id !== numericId);

        delete nextExpires[String(numericId)];
        setPopupList(nextPopups, nextExpires);
    }

    function dismissPopup(id) {
        const popup = popups.find(item => item.id === Number(id));

        removePopup(id);

        if (popup?.notification)
            popup.notification.dismiss();
    }

    function invokePopupAction(id, action) {
        removePopup(id);

        if (action?.invoke)
            action.invoke();
    }

    function pruneExpired() {
        const now = Date.now();
        const nextExpires = Object.assign({}, expiresAtById);
        const nextPopups = popups.filter(popup => Number(nextExpires[String(popup.id)] ?? 0) > now);

        if (nextPopups.length !== popups.length)
            setPopupList(nextPopups, nextExpires);
    }

    function pruneResolved() {
        const activeIds = {};

        for (const notification of FeedHubState.notifications)
            activeIds[String(notification?.id ?? "")] = true;

        const nextExpires = Object.assign({}, expiresAtById);
        const nextPopups = popups.filter(popup => activeIds[String(popup.id)]);

        if (nextPopups.length !== popups.length)
            setPopupList(nextPopups, nextExpires);
    }

    function revealNewestPopup() {
        const maximumContentY = Math.max(0, popupViewport.contentHeight - popupViewport.height);

        popupViewport.contentY = root.topPosition ? 0 : maximumContentY;
    }

    onEffectiveMaxVisibleChanged: {
        if (popups.length > effectiveMaxVisible)
            setPopupList(popups.slice(0, effectiveMaxVisible), Object.assign({}, expiresAtById));
    }

    onImplicitHeightChanged: Qt.callLater(root.revealNewestPopup)
    onOrderedPopupsChanged: Qt.callLater(root.revealNewestPopup)

    Flickable {
        id: popupViewport

        width: root.implicitWidth
        height: root.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: popupStack.implicitHeight
        contentWidth: width
        interactive: contentHeight > height
        onContentHeightChanged: Qt.callLater(root.revealNewestPopup)

        Column {
            id: popupStack

            width: popupViewport.width
            spacing: 8

            Repeater {
                model: root.orderedPopups

                FeedHubNotificationPopupItem {
                    required property var modelData

                    width: popupStack.width
                    maximumHeight: root.maximumStackHeight
                    notification: modelData.notification
                    onActionInvoked: (notificationId, action) => root.invokePopupAction(notificationId, action)
                    onDismissRequested: notificationId => root.dismissPopup(notificationId)
                }
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0
        onTriggered: root.pruneExpired()
    }

    Connections {
        target: FeedHubState

        function onNotificationReceived(notification) {
            root.pushPopup(notification);
        }

        function onRevisionChanged() {
            root.pruneResolved();
        }
    }

    Connections {
        target: GlobalMenu

        function onActiveMenuChanged() {
            if (GlobalMenu.activeMenu === "feed-hub")
                root.clearPopups();
        }
    }
}
