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

    visible: open

    function closeMenu() {
        root.open = false;
        root.submenuOpen = false;
        root.menuHandle = null;
        root.submenuHandle = null;
    }

    function openMenu(handle, anchorX, anchorY) {
        if (!handle)
            return;

        root.submenuOpen = false;
        root.submenuHandle = null;
        root.menuHandle = handle;
        root.open = true;
        menuOpener.menu = handle;
        Qt.callLater(() => root.positionPopup(popup, anchorX, anchorY));
    }

    function openSubmenu(handle, anchorX, anchorY) {
        if (!handle)
            return;

        root.submenuHandle = handle;
        root.submenuOpen = true;
        submenuOpener.menu = handle;
        Qt.callLater(() => {
            const rightX = popup.x + popup.width + root.submenuGap;
            const leftX = popup.x - submenuPopup.width - root.submenuGap;
            const requestedX = rightX + submenuPopup.width + root.popupMargin <= root.width ? rightX : leftX;

            root.positionPopup(submenuPopup, requestedX, popup.y + anchorY);
        });
    }

    function positionPopup(target, requestedX, requestedY) {
        const maxX = Math.max(root.popupMargin, root.width - target.width - root.popupMargin);
        const maxY = Math.max(root.popupMargin, root.height - target.height - root.popupMargin);

        target.x = Math.max(root.popupMargin, Math.min(requestedX, maxX));
        target.y = Math.max(root.popupMargin, Math.min(requestedY, maxY));
    }

    onHeightChanged: {
        if (open)
            positionPopup(popup, popup.x, popup.y);
        if (submenuOpen)
            positionPopup(submenuPopup, submenuPopup.x, submenuPopup.y);
    }
    onOpenChanged: {
        if (!open)
            menuOpener.menu = null;
    }
    onSubmenuOpenChanged: {
        if (!submenuOpen)
            submenuOpener.menu = null;
    }
    onWidthChanged: {
        if (open)
            positionPopup(popup, popup.x, popup.y);
        if (submenuOpen)
            positionPopup(submenuPopup, submenuPopup.x, submenuPopup.y);
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
        height: Math.min(root.height - root.popupMargin * 2, menuColumn.implicitHeight + 10)
        border.color: Colors.widgetBorder
        border.width: 1
        color: Colors.widgetBg
        radius: 8
        visible: root.open
        z: 1

        Flickable {
            anchors {
                fill: parent
                margins: 5
            }

            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: menuColumn.implicitHeight
            contentWidth: width

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
                        onSubmenuRequested: (entry, x, y) => root.openSubmenu(entry, x, y)
                    }
                }
            }
        }
    }

    Rectangle {
        id: submenuPopup

        width: 240
        height: Math.min(root.height - root.popupMargin * 2, submenuColumn.implicitHeight + 10)
        border.color: Colors.widgetBorder
        border.width: 1
        color: Colors.widgetBg
        radius: 8
        visible: root.submenuOpen
        z: 2

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
                        onSubmenuRequested: (entry, x, y) => root.openSubmenu(entry, x, y)
                    }
                }
            }
        }
    }
}
