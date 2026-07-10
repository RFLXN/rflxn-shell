pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../../../theme"

Item {
    id: root

    property int popupMargin: 6
    property int submenuGap: 2
    property var menuHandle
    property var submenuHandle
    property bool open: false
    property bool submenuOpen: false
    property int menuRequestRevision: 0
    property int submenuRequestRevision: 0
    property real menuAnchorX: 0
    property real menuAnchorY: 0
    property real submenuAnchorLeft: 0
    property real submenuAnchorRight: 0
    property real submenuAnchorY: 0

    visible: open

    function closeSubmenu() {
        submenuRequestRevision += 1;
        root.submenuOpen = false;
        root.submenuHandle = null;
        submenuOpener.menu = null;
    }

    function closeMenu() {
        menuRequestRevision += 1;
        root.open = false;
        root.menuHandle = null;
        menuOpener.menu = null;
        closeSubmenu();
    }

    function openMenu(handle, anchorX, anchorY) {
        if (!handle)
            return;

        closeSubmenu();
        const requestRevision = ++menuRequestRevision;

        root.menuAnchorX = anchorX;
        root.menuAnchorY = anchorY;
        root.menuHandle = handle;
        menuOpener.menu = handle;
        root.open = true;
        Qt.callLater(() => {
            if (root.open && root.menuHandle === handle && root.menuRequestRevision === requestRevision)
                root.positionPopup(popup, root.menuAnchorX, root.menuAnchorY);
        });
    }

    function openSubmenu(handle, anchorItem) {
        if (!handle || !anchorItem)
            return;

        const anchorPoint = anchorItem.mapToItem(root, 0, 0);

        closeSubmenu();
        const requestRevision = ++submenuRequestRevision;

        root.submenuAnchorLeft = anchorPoint.x;
        root.submenuAnchorRight = anchorPoint.x + anchorItem.width;
        root.submenuAnchorY = anchorPoint.y;
        root.submenuHandle = handle;
        submenuOpener.menu = handle;
        root.submenuOpen = true;
        Qt.callLater(() => {
            if (root.submenuOpen && root.submenuHandle === handle && root.submenuRequestRevision === requestRevision)
                root.positionSubmenu();
        });
    }

    function positionSubmenu() {
        const rightX = submenuAnchorRight + submenuGap;
        const leftX = submenuAnchorLeft - submenuPopup.width - submenuGap;
        const requestedX = rightX + submenuPopup.width + popupMargin <= width ? rightX : leftX;

        positionPopup(submenuPopup, requestedX, submenuAnchorY);
    }

    function positionPopup(target, requestedX, requestedY) {
        const maxX = Math.max(root.popupMargin, root.width - target.width - root.popupMargin);
        const maxY = Math.max(root.popupMargin, root.height - target.height - root.popupMargin);

        target.x = Math.max(root.popupMargin, Math.min(requestedX, maxX));
        target.y = Math.max(root.popupMargin, Math.min(requestedY, maxY));
    }

    onHeightChanged: {
        if (open)
            positionPopup(popup, menuAnchorX, menuAnchorY);
        if (submenuOpen)
            positionSubmenu();
    }
    onMenuHandleChanged: {
        if (open && !menuHandle)
            closeMenu();
    }
    onOpenChanged: {
        if (!open) {
            menuRequestRevision += 1;
            root.menuHandle = null;
            menuOpener.menu = null;
            closeSubmenu();
        }
    }
    onSubmenuOpenChanged: {
        if (!submenuOpen) {
            root.submenuHandle = null;
            submenuOpener.menu = null;
        }
    }
    onSubmenuHandleChanged: {
        if (submenuOpen && !submenuHandle)
            closeSubmenu();
    }
    onWidthChanged: {
        if (open)
            positionPopup(popup, menuAnchorX, menuAnchorY);
        if (submenuOpen)
            positionSubmenu();
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.closeMenu()
    }

    QsMenuOpener {
        id: menuOpener
    }

    QsMenuOpener {
        id: submenuOpener
    }

    Rectangle {
        id: popup

        width: 240
        height: Math.max(1, Math.min(root.height - root.popupMargin * 2, menuColumn.implicitHeight + 10))
        border.color: Colors.widgetBorder
        border.width: 1
        color: Colors.widgetBg
        radius: 8
        visible: root.open
        z: 1

        onHeightChanged: {
            if (root.open)
                root.positionPopup(popup, root.menuAnchorX, root.menuAnchorY);
        }

        Flickable {
            anchors {
                fill: parent
                margins: 5
            }

            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: menuColumn.implicitHeight
            contentWidth: width
            onMovementStarted: root.closeSubmenu()

            Column {
                id: menuColumn

                width: parent.width
                spacing: 2

                Repeater {
                    model: menuOpener.children.values

                    FeedHubTrayMenuItem {
                        required property var modelData

                        width: menuColumn.width
                        entry: modelData
                        onActivated: root.closeMenu()
                        onSubmenuDismissRequested: root.closeSubmenu()
                        onSubmenuRequested: (entry, anchorItem) => root.openSubmenu(entry, anchorItem)
                    }
                }
            }
        }
    }

    Rectangle {
        id: submenuPopup

        width: 240
        height: Math.max(1, Math.min(root.height - root.popupMargin * 2, submenuColumn.implicitHeight + 10))
        border.color: Colors.widgetBorder
        border.width: 1
        color: Colors.widgetBg
        radius: 8
        visible: root.submenuOpen
        z: 2

        onHeightChanged: {
            if (root.submenuOpen)
                root.positionSubmenu();
        }

        Flickable {
            anchors {
                fill: parent
                margins: 5
            }

            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: submenuColumn.implicitHeight
            contentWidth: width

            Column {
                id: submenuColumn

                width: parent.width
                spacing: 2

                Repeater {
                    model: submenuOpener.children.values

                    FeedHubTrayMenuItem {
                        required property var modelData

                        width: submenuColumn.width
                        entry: modelData
                        onActivated: root.closeMenu()
                        onSubmenuRequested: (entry, anchorItem) => root.openSubmenu(entry, anchorItem)
                    }
                }
            }
        }
    }
}
