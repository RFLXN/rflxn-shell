import Quickshell.Services.Pipewire
import QtQuick
import "../../../theme"

Item {
    id: root

    property bool active: false
    property int iconPixelSize: Metrics.compactIconSize
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

            ProgressRing {
                id: ring

                anchors.centerIn: parent
                width: parent.width + root.ringCanvasPadding * 2
                height: parent.height + root.ringCanvasPadding * 2
                canvasPadding: root.ringCanvasPadding
                indicatorColor: root.indicatorColor
                progress: root.progressTarget
            }

            Text {
                anchors.centerIn: parent
                color: root.indicatorColor
                font.family: Typography.iconFamily
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
            font.family: Typography.textFamily
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
}
