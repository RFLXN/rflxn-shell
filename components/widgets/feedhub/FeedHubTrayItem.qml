import Quickshell.Widgets
import QtQuick
import "../../../theme"

Rectangle {
    id: root

    property var menuPresenter
    property var trayItem
    readonly property string iconName: String(trayItem?.icon ?? "")
    readonly property string tooltipText: String(trayItem?.tooltipTitle || trayItem?.title || trayItem?.id || "")

    width: 26
    height: 26
    color: pointerArea.containsMouse ? Colors.widgetBgHover : "transparent"
    radius: height / 2

    function showMenu(mouse) {
        if (!trayItem)
            return;

        if (trayItem.hasMenu) {
            if (menuPresenter) {
                const point = root.mapToItem(menuPresenter, mouse.x, mouse.y);
                menuPresenter.openMenu(trayItem.menu, Math.round(point.x), Math.round(point.y));
            }
            return;
        }

        trayItem.secondaryActivate();
    }

    function iconSource() {
        if (!iconName)
            return "";

        if (iconName.startsWith("image://") || iconName.startsWith("file://") || iconName.startsWith("/"))
            return iconName;

        return `image://icon/${iconName}`;
    }

    IconImage {
        id: trayIcon

        anchors.centerIn: parent
        width: 18
        height: 18
        asynchronous: true
        implicitSize: 18
        mipmap: true
        source: root.iconSource()
        visible: source !== "" && status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        color: Colors.textSecondary
        font.family: Typography.iconFamily
        font.pixelSize: 14
        text: "\uf1c5"
        visible: !trayIcon.visible
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: mouse => {
            if (!root.trayItem)
                return;

            if (mouse.button === Qt.RightButton || root.trayItem.onlyMenu) {
                root.showMenu(mouse);
                return;
            }

            root.trayItem.activate();
        }
    }
}
