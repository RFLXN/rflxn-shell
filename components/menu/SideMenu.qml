import Quickshell
import QtQuick
import "../../theme"
import "../state"

PanelWindow {
    id: root

    default property alias contentData: body.data
    property int contentPadding: 18
    property int cornerRadius: 23
    property int menuMargin: 6
    property int menuHeight: 560
    property int menuTopOffset: 0
    property int menuWidth: 420
    property string alignment: "center"
    property var modelData
    property string direction: "left"
    property string menuId: ""
    property string screenName: ""
    property bool animateDrawer: false
    property bool mounted: false
    property bool openingQueued: false
    property bool visualOpen: false
    readonly property alias overlayContainer: overlayLayer
    readonly property bool geometryReady: shell.width > 0 && shell.height > 0
    readonly property bool menuOpen: GlobalMenu.isMenuOpen(menuId, screenName)
    readonly property bool opensFromBottom: direction === "bottom"
    readonly property bool opensFromRight: direction === "right"
    readonly property bool opensFromTop: direction === "top"
    readonly property bool horizontalEdge: opensFromTop || opensFromBottom

    screen: modelData

    anchors {
        bottom: true
        left: true
        right: true
        top: true
    }

    color: "transparent"
    exclusiveZone: 0
    focusable: menuOpen
    mask: Region {
        item: root.menuOpen ? shell : null
    }
    surfaceFormat.opaque: false
    visible: mounted

    function closedX() {
        if (horizontalEdge)
            return openX();

        return opensFromRight ? shell.width + 2 : -drawer.width - 2;
    }

    function closedY() {
        if (!horizontalEdge)
            return openY();

        return opensFromBottom ? shell.height + 2 : -drawer.height - 2;
    }

    function openX() {
        if (horizontalEdge) {
            if (alignment === "left")
                return menuMargin;

            if (alignment === "right")
                return shell.width - drawer.width - menuMargin;

            return Math.max(menuMargin, (shell.width - drawer.width) / 2);
        }

        return opensFromRight ? shell.width - drawer.width - menuMargin : menuMargin;
    }

    function openY() {
        if (horizontalEdge)
            return opensFromBottom ? shell.height - drawer.height - menuMargin : menuMargin;

        return menuMargin + menuTopOffset;
    }

    function drawerWidth() {
        const availableWidth = Math.max(0, shell.width - menuMargin * 2);

        return Math.min(menuWidth, availableWidth);
    }

    function drawerHeight() {
        if (horizontalEdge)
            return Math.max(0, Math.min(menuHeight, shell.height - menuMargin * 2));

        return Math.max(0, shell.height - openY() - menuMargin);
    }

    function prepareOpen() {
        if (!mounted || !menuOpen || !geometryReady || openingQueued)
            return;

        animateDrawer = false;
        visualOpen = false;
        openingQueued = true;
        openTimer.restart();
    }

    onGeometryReadyChanged: {
        if (geometryReady && menuOpen)
            prepareOpen();
    }

    onMenuOpenChanged: {
        if (menuOpen) {
            unmountTimer.stop();
            if (mounted && geometryReady) {
                animateDrawer = true;
                visualOpen = true;
            } else {
                animateDrawer = false;
                visualOpen = false;
                mounted = true;
                prepareOpen();
            }
            return;
        }

        openTimer.stop();
        openingQueued = false;
        animateDrawer = true;
        visualOpen = false;
        unmountTimer.restart();
    }

    Component.onCompleted: {
        mounted = menuOpen;
        if (menuOpen)
            prepareOpen();
    }

    Timer {
        id: openTimer

        interval: 0
        repeat: false

        onTriggered: {
            root.openingQueued = false;

            if (!root.mounted || !root.menuOpen || !root.geometryReady)
                return;

            root.animateDrawer = true;
            root.visualOpen = true;
        }
    }

    Timer {
        id: unmountTimer

        interval: GlobalMenu.transitionDuration
        repeat: false

        onTriggered: root.mounted = false
    }

    Item {
        id: shell

        anchors.fill: parent
        focus: root.menuOpen

        Keys.onEscapePressed: event => {
            GlobalMenu.closeActiveMenu();
            event.accepted = true;
        }

        Rectangle {
            id: scrim

            anchors.fill: parent
            color: "#000000"
            opacity: root.visualOpen ? 0.01 : 0
            z: 0

            MouseArea {
                anchors.fill: parent
                enabled: root.visualOpen
                onClicked: GlobalMenu.closeActiveMenu()
            }
        }

        Rectangle {
            id: drawer

            x: root.visualOpen ? root.openX() : root.closedX()
            y: root.visualOpen ? root.openY() : root.closedY()
            width: root.drawerWidth()
            height: root.drawerHeight()
            border.color: Colors.widgetBorder
            border.width: 1
            clip: true
            color: Colors.widgetBg
            opacity: root.geometryReady ? 1 : 0
            radius: root.cornerRadius
            topLeftRadius: root.opensFromTop ? 0 : root.cornerRadius
            topRightRadius: root.opensFromTop ? 0 : root.cornerRadius
            bottomLeftRadius: root.opensFromBottom ? 0 : root.cornerRadius
            bottomRightRadius: root.opensFromBottom ? 0 : root.cornerRadius
            z: 1

            Behavior on x {
                enabled: root.animateDrawer

                NumberAnimation {
                    duration: GlobalMenu.transitionDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                enabled: root.animateDrawer

                NumberAnimation {
                    duration: GlobalMenu.transitionDuration
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                anchors {
                    fill: parent
                    margins: root.contentPadding
                }

                Item {
                    id: body

                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }

                    clip: true
                }
            }
        }

        Item {
            id: overlayLayer

            anchors.fill: parent
            z: 2
        }
    }
}
