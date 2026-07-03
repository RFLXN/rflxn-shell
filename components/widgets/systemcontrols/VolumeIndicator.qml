import Quickshell.Services.Pipewire
import QtQuick
import "../../../theme"

Item {
    id: root

    property bool active: false
    property int iconPixelSize: Metrics.compactIconSize
    property real progress: 0
    property int ringCanvasPadding: 1
    property int ringSize: Metrics.compactIndicatorSize
    property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio
    readonly property bool boosted: !muted && volumePercent > 100
    readonly property bool hasSink: sink !== null && sink !== undefined && audio !== null && audio !== undefined
    readonly property color indicatorColor: muted ? Colors.critical : boosted ? Colors.warning : active ? Colors.textPrimary : Colors.textSecondary
    readonly property string iconText: muted ? "\uf026" : "\uf027"
    readonly property bool muted: hasSink && audio.muted
    readonly property real progressTarget: muted ? 0 : Math.max(0, Math.min(volume, 1))
    readonly property real volume: hasSink ? audio.volume : 0
    readonly property int volumePercent: Math.round(Math.max(0, volume) * 100)

    width: implicitWidth
    height: ringSize
    implicitWidth: content.implicitWidth
    implicitHeight: ringSize

    onProgressTargetChanged: progress = progressTarget

    Component.onCompleted: progress = progressTarget

    Behavior on progress {
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutQuad
        }
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    Row {
        id: content

        anchors.centerIn: parent
        layoutDirection: Qt.RightToLeft
        spacing: 3

        Item {
            id: progressIcon

            width: root.ringSize
            height: root.ringSize

            Canvas {
                id: ring

                anchors.centerIn: parent
                width: parent.width + root.ringCanvasPadding * 2
                height: parent.height + root.ringCanvasPadding * 2

                onPaint: {
                    const ctx = getContext("2d");
                    const actualSize = Math.min(parent.width, parent.height);
                    const lineWidth = Math.max(2, actualSize * 0.1);
                    const radius = (actualSize - lineWidth) / 2;
                    const centerX = width / 2;
                    const centerY = height / 2;
                    const start = -Math.PI / 2;
                    const end = start + Math.PI * 2 * root.progress;

                    ctx.clearRect(0, 0, width, height);
                    ctx.lineWidth = lineWidth;
                    ctx.lineCap = "round";

                    ctx.strokeStyle = Qt.rgba(root.indicatorColor.r, root.indicatorColor.g, root.indicatorColor.b, 0.24);
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                    ctx.stroke();

                    if (root.progress <= 0)
                        return;

                    ctx.strokeStyle = root.indicatorColor;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, start, end);
                    ctx.stroke();
                }

                onHeightChanged: requestPaint()
                onWidthChanged: requestPaint()
            }

            Text {
                anchors.centerIn: parent
                color: root.indicatorColor
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: root.iconPixelSize
                horizontalAlignment: Text.AlignHCenter
                text: root.iconText
                verticalAlignment: Text.AlignVCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }

        Text {
            id: percentLabel

            anchors.verticalCenter: parent.verticalCenter
            color: root.active ? Colors.textPrimary : Colors.textSecondary
            font.family: "Pretendard"
            font.pixelSize: 14
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignRight
            text: root.hasSink ? String(root.volumePercent) : "--"
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
                ColorAnimation {
                    duration: 160
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    onIndicatorColorChanged: ring.requestPaint()
    onProgressChanged: ring.requestPaint()
}
