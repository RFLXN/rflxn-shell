pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"

Item {
    id: root

    property var currentNode
    property var devices: []
    property string emptyText: "No devices"
    property string icon: "\uf028"
    property string mutedIcon: "\uf026"
    property real maxVolume: 1
    property bool selectorOpen: false
    property string title: "Audio"
    property string unmutedIcon: "\uf028"
    readonly property var audio: currentNode?.audio
    readonly property bool hasDevice: currentNode !== null && currentNode !== undefined && audio !== null && audio !== undefined
    readonly property bool muted: hasDevice && audio.muted
    readonly property real safeMaxVolume: Math.max(0.01, maxVolume)
    readonly property real volume: hasDevice ? Math.max(0, audio.volume) : 0
    readonly property int volumePercent: Math.round(volume * 100)

    signal deviceSelected(var device)
    signal selectorToggled()

    width: parent?.width ?? 360
    height: content.implicitHeight
    implicitHeight: content.implicitHeight

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function deviceLabel(device) {
        const description = String(device?.description ?? "").trim();
        const nickname = String(device?.nickname ?? "").trim();
        const name = String(device?.name ?? "").trim();

        return description || nickname || name || "Unknown device";
    }

    function nodeMatches(left, right) {
        return Number(left?.id ?? -1) === Number(right?.id ?? -2);
    }

    function setVolumeFromPosition(item, x) {
        if (!root.hasDevice)
            return;

        const ratio = clamp(x / Math.max(1, item.width), 0, 1);
        const nextVolume = ratio * root.safeMaxVolume;

        root.audio.volume = nextVolume;

        if (nextVolume > 0 && root.audio.muted)
            root.audio.muted = false;
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        Row {
            width: parent.width
            height: 20
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                color: Colors.textMuted
                font.family: Typography.iconFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                text: root.icon
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.textMuted
                font.family: Typography.textFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                text: root.title
            }
        }

        Rectangle {
            id: selector

            width: parent.width
            height: 34
            border.color: root.selectorOpen ? Colors.accent : "transparent"
            border.width: root.selectorOpen ? 1 : 0
            color: selectorArea.containsMouse || root.selectorOpen ? Colors.widgetBgHover : "transparent"
            radius: 10

            Row {
                anchors {
                    left: parent.left
                    leftMargin: 10
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }

                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - arrow.width - 8
                    color: root.hasDevice ? Colors.textPrimary : Colors.textMuted
                    elide: Text.ElideRight
                    font.family: Typography.textFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    text: root.hasDevice ? root.deviceLabel(root.currentNode) : root.emptyText
                }

                Text {
                    id: arrow

                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    color: root.selectorOpen ? Colors.accent : Colors.textSecondary
                    font.family: Typography.iconFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    text: root.selectorOpen ? "\uf077" : "\uf078"
                }
            }

            MouseArea {
                id: selectorArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.selectorToggled()
            }
        }

        Column {
            width: parent.width
            spacing: 2
            visible: root.selectorOpen

            Repeater {
                model: root.devices

                Rectangle {
                    id: deviceRow

                    required property var modelData
                    readonly property bool selected: root.nodeMatches(deviceRow.modelData, root.currentNode)

                    width: parent.width
                    height: 28
                    color: selected ? Colors.accentSoft : rowArea.containsMouse ? Colors.widgetBgHover : "transparent"
                    radius: 8

                    Row {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }

                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            color: deviceRow.selected ? Colors.accent : "transparent"
                            font.family: Typography.iconFamily
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            text: "\uf00c"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 22
                            color: deviceRow.selected ? Colors.textPrimary : Colors.textSecondary
                            elide: Text.ElideRight
                            font.family: Typography.textFamily
                            font.pixelSize: 12
                            text: root.deviceLabel(deviceRow.modelData)
                        }
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.deviceSelected(deviceRow.modelData)
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 30
            enabled: root.hasDevice
            opacity: root.hasDevice ? 1 : 0.45
            spacing: 8

            Item {
                id: slider

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - muteButton.width - percentLabel.width - parent.spacing * 2
                height: 24

                Rectangle {
                    id: track

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    height: 6
                    color: Colors.widgetBgHover
                    radius: height / 2
                }

                Rectangle {
                    anchors {
                        left: track.left
                        verticalCenter: track.verticalCenter
                    }

                    width: track.width * root.clamp(root.volume / root.safeMaxVolume, 0, 1)
                    height: track.height
                    color: root.muted ? Colors.critical : (sliderArea.containsMouse || sliderArea.pressed ? Colors.accent : Colors.accentSoft)
                    radius: height / 2
                }

                Rectangle {
                    x: root.clamp(track.width * root.volume / root.safeMaxVolume - width / 2, 0, Math.max(0, slider.width - width))
                    anchors.verticalCenter: track.verticalCenter
                    width: sliderArea.containsMouse || sliderArea.pressed ? 12 : 8
                    height: width
                    color: root.muted ? Colors.critical : Colors.accent
                    radius: height / 2

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: sliderArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.hasDevice
                    hoverEnabled: true
                    onPositionChanged: {
                        if (pressed)
                            root.setVolumeFromPosition(slider, mouseX);
                    }
                    onPressed: root.setVolumeFromPosition(slider, mouseX)
                }
            }

            Text {
                id: percentLabel

                anchors.verticalCenter: parent.verticalCenter
                width: 42
                color: root.muted ? Colors.critical : Colors.textSecondary
                font.family: Typography.textFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                horizontalAlignment: Text.AlignRight
                text: root.hasDevice ? (root.muted ? "Muted" : `${root.volumePercent}%`) : "--"
            }

            Rectangle {
                id: muteButton

                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                color: muteArea.containsMouse ? Colors.widgetBgHover : "transparent"
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    color: root.muted ? Colors.critical : (muteArea.containsMouse ? Colors.textPrimary : Colors.textSecondary)
                    font.family: Typography.iconFamily
                    font.pixelSize: 13
                    text: root.muted ? root.mutedIcon : root.unmutedIcon
                }

                MouseArea {
                    id: muteArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.hasDevice
                    hoverEnabled: true
                    onClicked: root.audio.muted = !root.audio.muted
                }
            }
        }
    }
}
