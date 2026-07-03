import Quickshell.Hyprland
import QtQuick
import "../../../theme"
import "../../state"

Rectangle {
    id: root

    property string menuId: "feed-hub"
    property var screen
    readonly property bool active: GlobalMenu.isMenuOpen(menuId, screenName)
    readonly property bool hovered: triggerArea.containsMouse
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property string detectedScreenName: monitor?.name ?? ""
    property string screenName: detectedScreenName
    readonly property string iconPath: "M160-120q-33 0-56.5-23.5T80-200v-240q0-17 11.5-28.5T120-480q17 0 28.5 11.5T160-440v240h320q17 0 28.5 11.5T520-160q0 17-11.5 28.5T480-120H160Zm160-160q-33 0-56.5-23.5T240-360v-240q0-17 11.5-28.5T280-640q17 0 28.5 11.5T320-600v240h320q17 0 28.5 11.5T680-320q0 17-11.5 28.5T640-280H320Zm160-160q-33 0-56.5-23.5T400-520v-240q0-33 23.5-56.5T480-840h320q33 0 56.5 23.5T880-760v240q0 33-23.5 56.5T800-440H480Zm0-80h320v-160H480v160Z"

    width: 32
    height: 32
    color: "transparent"
    radius: height / 2

    function colorToSvg(value) {
        const red = Math.round(value.r * 255);
        const green = Math.round(value.g * 255);
        const blue = Math.round(value.b * 255);

        return `rgb(${red},${green},${blue})`;
    }

    function svgSource(path, color) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 -960 960 960"><path fill="${colorToSvg(color)}" d="${path}"/></svg>`;

        return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    }

    Rectangle {
        id: iconContainer

        anchors.centerIn: parent
        width: 32
        height: 32
        color: root.active || root.hovered ? Colors.accentStrong : Colors.accent
        radius: height / 2

        Behavior on color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            asynchronous: true
            mipmap: true
            source: root.svgSource(root.iconPath, Colors.textOnAccent)
            sourceSize.width: width
            sourceSize.height: height
        }
    }

    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
        }

        width: 7
        height: 7
        color: Colors.critical
        radius: height / 2
        visible: FeedHubState.hasNotifications
    }

    MouseArea {
        id: triggerArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: GlobalMenu.toggleMenu(root.menuId, root.screenName)
    }
}
