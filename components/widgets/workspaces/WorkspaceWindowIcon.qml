import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import "../../../theme"

Item {
    id: root

    property string presenceKey: ""
    property bool urgent: false
    property bool entering: false
    property bool exiting: false
    property var window
    property bool focusAnimationReady: false
    property int itemSize: Metrics.widgetHeight
    property int iconSize: Metrics.workspaceWindowIconSize
    readonly property bool focused: window?.focused ?? false
    readonly property color foreground: urgent ? "#15110a" : (window?.focused ? Colors.textPrimary : Colors.textSecondary)
    readonly property string fallbackText: fallbackLabel(window?.label || window?.title || "?")
    readonly property string iconName: String(window?.icon ?? "")
    signal exitFinished(string key)

    width: itemSize
    height: itemSize
    transformOrigin: Item.Center

    function fallbackLabel(value) {
        const text = String(value ?? "").trim();

        if (text.length === 0)
            return "?";

        return text.charAt(0).toUpperCase();
    }

    Behavior on x {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: focusPopAnimation

        NumberAnimation {
            target: content
            property: "scale"
            to: 1.18
            duration: 140
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: content
            property: "scale"
            to: 1
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: 440
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 440
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: 0.72
            duration: 440
            easing.type: Easing.InCubic
        }

        onFinished: root.exitFinished(root.presenceKey)
    }

    Item {
        id: content

        anchors.fill: parent
        transformOrigin: Item.Center

        IconImage {
            id: iconImage

            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            asynchronous: true
            implicitSize: root.iconSize
            mipmap: true
            source: root.iconName ? `image://icon/${root.iconName}` : ""
            visible: source !== "" && status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            color: root.foreground
            font.family: Typography.textFamily
            font.pixelSize: 14
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: root.fallbackText
            verticalAlignment: Text.AlignVCenter
            visible: !iconImage.visible

            Behavior on color {
                ColorAnimation {
                    duration: 180
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    HoverHandler {
        enabled: !root.exiting
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !root.exiting

        onTapped: Hyprland.dispatch(`focuswindow address:${root.window.address}`)
    }

    onExitingChanged: {
        if (root.exiting) {
            enterAnimation.stop();
            focusPopAnimation.stop();
            content.scale = 1;
            exitAnimation.restart();
            return;
        }

        if (root.opacity < 1 || root.scale < 1) {
            exitAnimation.stop();
            enterAnimation.restart();
        }
    }

    onFocusedChanged: {
        if (!root.focusAnimationReady || !root.focused || root.exiting)
            return;

        focusPopAnimation.restart();
    }

    Component.onCompleted: {
        if (root.exiting) {
            root.opacity = 1;
            root.scale = 1;
            exitAnimation.restart();
            return;
        }

        if (!root.entering) {
            root.focusAnimationReady = true;
            return;
        }

        root.opacity = 0;
        root.scale = 0.72;
        enterAnimation.restart();
        root.focusAnimationReady = true;
    }
}
