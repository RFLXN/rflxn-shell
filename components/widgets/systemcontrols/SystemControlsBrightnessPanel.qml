pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../state"

Rectangle {
    id: root

    property bool pollingActive: false
    property bool pollingAcquired: false
    readonly property int brightnessPercent: BrightnessState.percent
    readonly property bool controlAvailable: BrightnessState.available
    readonly property bool controlSucceeded: BrightnessState.lastSetSucceeded
    readonly property bool pollingRequested: pollingActive

    width: parent?.width ?? 380
    height: content.implicitHeight + 24
    border.color: Colors.widgetBorder
    border.width: 1
    color: Colors.barBg
    radius: 12

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function setBrightnessFromPosition(item, x) {
        if (!root.controlAvailable)
            return;

        const ratio = root.clamp(x / Math.max(1, item.width), 0, 1);
        const nextPercent = Math.max(1, Math.round(ratio * 100));

        BrightnessState.setPercent(nextPercent);
    }

    function statusDescription() {
        if (!root.controlSucceeded)
            return "Unable to change display brightness";

        const displayName = BrightnessState.internalDisplayName || "Internal display";

        return `${displayName} · ${root.brightnessPercent}%`;
    }

    function syncPolling() {
        if (root.pollingRequested === root.pollingAcquired)
            return;

        root.pollingAcquired = root.pollingRequested;

        if (root.pollingAcquired) {
            BrightnessState.acquirePolling();
        } else {
            BrightnessState.releasePolling();
        }
    }

    onPollingActiveChanged: root.syncPolling()

    Column {
        id: content

        anchors {
            left: parent.left
            leftMargin: 12
            right: parent.right
            rightMargin: 12
            top: parent.top
            topMargin: 12
        }

        spacing: 10

        Item {
            width: parent.width
            height: 42

            Row {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    color: Colors.accentSoft
                    radius: height / 2

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        color: Colors.accent
                        font.family: Typography.iconFamily
                        font.pixelSize: 16
                        text: "\uf185"
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44
                    spacing: 2

                    Text {
                        width: parent.width
                        color: Colors.textPrimary
                        font.family: Typography.textFamily
                        font.pixelSize: 14
                        font.weight: Font.ExtraBold
                        text: "Brightness"
                    }

                    Text {
                        width: parent.width
                        color: root.controlSucceeded ? Colors.textMuted : Colors.critical
                        elide: Text.ElideRight
                        font.family: Typography.textFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: root.statusDescription()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.separator
        }

        Row {
            width: parent.width
            height: 30
            enabled: root.controlAvailable
            opacity: enabled ? 1 : 0.45
            spacing: 8

            Item {
                id: slider

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - percentLabel.width - parent.spacing
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

                    width: track.width * root.clamp(root.brightnessPercent / 100, 0, 1)
                    height: track.height
                    color: sliderArea.containsMouse || sliderArea.pressed ? Colors.accent : Colors.accentSoft
                    radius: height / 2
                }

                Rectangle {
                    x: root.clamp(track.width * root.brightnessPercent / 100 - width / 2, 0, Math.max(0, slider.width - width))
                    anchors.verticalCenter: track.verticalCenter
                    width: sliderArea.containsMouse || sliderArea.pressed ? 12 : 8
                    height: width
                    color: Colors.accent
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
                    enabled: root.controlAvailable
                    hoverEnabled: true

                    onPositionChanged: {
                        if (pressed)
                            root.setBrightnessFromPosition(slider, mouseX);
                    }
                    onPressed: root.setBrightnessFromPosition(slider, mouseX)
                }
            }

            Text {
                id: percentLabel

                anchors.verticalCenter: parent.verticalCenter
                width: 42
                color: root.controlSucceeded ? Colors.textSecondary : Colors.critical
                font.family: Typography.textFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                horizontalAlignment: Text.AlignRight
                text: `${root.brightnessPercent}%`
            }
        }
    }

    Component.onCompleted: root.syncPolling()

    Component.onDestruction: {
        if (root.pollingAcquired)
            BrightnessState.releasePolling();
    }
}
