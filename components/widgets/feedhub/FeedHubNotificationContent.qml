pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import "../../../theme"

Column {
    id: root

    property var notification
    property real imageFallbackHeight: 120
    property real imageMaximumHeight: 180
    property real imageMinimumHeight: 72
    property bool showRelativeTime: false
    property string relativeTime: ""
    readonly property string appName: String(notification?.appName || notification?.desktopEntry || "Application")
    readonly property string appIconName: String(notification?.appIcon || notification?.desktopEntry || "")
    readonly property string title: String(notification?.summary || "Notification")
    readonly property string body: String(notification?.body || "")
    readonly property string imageSource: String(notification?.image || "")
    readonly property var actions: notification?.actions ?? []

    signal actionInvoked(var action)
    signal dismissRequested()

    spacing: 6

    Item {
        width: parent.width
        height: 22

        IconImage {
            id: appIcon

            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            asynchronous: true
            implicitSize: 14
            mipmap: true
            source: root.appIconName ? `image://icon/${root.appIconName}` : ""
            visible: source !== "" && status === Image.Ready
        }

        Text {
            id: appNameLabel

            anchors.verticalCenter: parent.verticalCenter
            x: appIcon.visible ? appIcon.width + 6 : 0
            width: Math.max(0, closeButton.x - appNameLabel.x - 6)
            color: Colors.textMuted
            elide: Text.ElideRight
            font.family: Typography.textFamily
            font.pixelSize: 12
            text: root.appName
        }

        Rectangle {
            id: closeButton

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            width: 22
            height: 22
            color: closeArea.containsMouse ? Colors.critical : "transparent"
            radius: height / 2

            Behavior on color {
                ColorAnimation {
                    duration: 160
                    easing.type: Easing.OutQuad
                }
            }

            Text {
                anchors.centerIn: parent
                color: closeArea.containsMouse ? Colors.textPrimary : Colors.textMuted
                font.family: Typography.iconFamily
                font.pixelSize: 14
                text: "\uf00d"
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.dismissRequested()
            }
        }
    }

    Text {
        width: parent.width
        color: Colors.textPrimary
        font.family: Typography.textFamily
        font.pixelSize: 14
        font.weight: Font.Bold
        text: root.title
        wrapMode: Text.WordWrap
    }

    Rectangle {
        id: imageFrame

        readonly property real scaledImageHeight: notificationImage.implicitWidth > 0 ? notificationImage.implicitHeight * width / notificationImage.implicitWidth : root.imageFallbackHeight

        width: parent.width
        height: visible ? Math.min(root.imageMaximumHeight, Math.max(root.imageMinimumHeight, scaledImageHeight)) : 0
        clip: true
        color: Colors.widgetBg
        radius: 8
        visible: root.imageSource !== "" && notificationImage.status === Image.Ready

        Image {
            id: notificationImage

            anchors.fill: parent
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            mipmap: true
            source: root.imageSource
            sourceSize.width: Math.max(1, Math.round(width))
        }
    }

    Text {
        width: parent.width
        color: Colors.textSecondary
        font.family: Typography.textFamily
        font.pixelSize: 13
        text: root.body
        visible: root.body.length > 0
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: 6
        visible: root.actions.length > 0

        Repeater {
            model: root.actions

            Rectangle {
                id: actionButton

                required property var modelData

                width: parent.width
                height: 26
                border.color: actionArea.containsMouse ? Colors.accent : Colors.widgetBorder
                border.width: 1
                color: actionArea.containsMouse ? Colors.accentSoft : Colors.widgetBg
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    color: Colors.textSecondary
                    elide: Text.ElideRight
                    font.family: Typography.textFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    text: String(actionButton.modelData?.text || actionButton.modelData?.identifier || "")
                }

                MouseArea {
                    id: actionArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.actionInvoked(actionButton.modelData)
                }
            }
        }
    }

    Text {
        width: parent.width
        color: Colors.textMuted
        font.family: Typography.textFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
        text: root.relativeTime
        visible: root.showRelativeTime
    }
}
