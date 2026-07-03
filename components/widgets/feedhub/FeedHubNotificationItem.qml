import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import "../../../theme"

Rectangle {
    id: root

    property var notification
    property string relativeTime: FeedHubState.formatNotificationTime(notification?.id ?? 0)
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property string appName: String(notification?.appName || notification?.desktopEntry || "Application")
    readonly property string appIconName: String(notification?.appIcon || notification?.desktopEntry || "")
    readonly property string title: String(notification?.summary || "Notification")
    readonly property string body: String(notification?.body || "")
    readonly property var actions: notification?.actions ?? []

    width: parent?.width ?? 420
    height: content.implicitHeight + 20
    color: critical ? Qt.rgba(Colors.critical.r, Colors.critical.g, Colors.critical.b, 0.22) : Colors.widgetBgHover
    radius: 14

    function dismiss() {
        if (notification)
            notification.dismiss();
    }

    Column {
        id: content

        anchors {
            left: parent.left
            leftMargin: 12
            right: parent.right
            rightMargin: 12
            top: parent.top
            topMargin: 10
        }

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
                font.family: "Pretendard"
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
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 14
                    text: "\uf00d"
                }

                MouseArea {
                    id: closeArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.dismiss()
                }
            }
        }

        Text {
            width: parent.width
            color: Colors.textPrimary
            font.family: "Pretendard"
            font.pixelSize: 14
            font.weight: Font.Bold
            text: root.title
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            color: Colors.textSecondary
            font.family: "Pretendard"
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
                        color: Colors.textSecondary
                        elide: Text.ElideRight
                        font.family: "Pretendard"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        text: String(modelData?.text || modelData?.identifier || "")
                        width: parent.width - 20
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: actionArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: modelData.invoke()
                    }
                }
            }
        }

        Text {
            width: parent.width
            color: Colors.textMuted
            font.family: "Pretendard"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            text: root.relativeTime
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.relativeTime = FeedHubState.formatNotificationTime(root.notification?.id ?? 0)
    }
}
