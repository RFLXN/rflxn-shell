import Quickshell.Services.UPower
import QtQuick
import QtQuick.Shapes
import "../../../theme"

Item {
    id: root

    property bool active: false
    property int iconPixelSize: Metrics.compactIconSize - 2
    property real progress: 0
    property int ringCanvasPadding: 1
    property int ringSize: Metrics.compactIndicatorSize
    readonly property var battery: UPower.displayDevice
    readonly property real batteryPercentRaw: available ? battery.percentage : 0
    readonly property int batteryPercent: Math.round(Math.max(0, Math.min(100, batteryPercentRaw <= 1 ? batteryPercentRaw * 100 : batteryPercentRaw)))
    readonly property bool available: battery !== null && battery !== undefined && battery.ready && battery.isPresent && battery.type === UPowerDeviceType.Battery
    readonly property bool charging: available && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
    readonly property bool critical: available && !charging && batteryPercent <= 10
    readonly property bool low: available && !charging && batteryPercent <= 20
    readonly property color indicatorColor: critical ? Colors.critical : low ? Colors.warning : charging ? Colors.accent : active ? Colors.textPrimary : Colors.textSecondary
    readonly property real progressTarget: available ? batteryPercent / 100 : 0

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

            Item {
                anchors.centerIn: parent
                width: root.iconPixelSize
                height: root.iconPixelSize

                Shape {
                    width: 960
                    height: 960
                    preferredRendererType: Shape.CurveRenderer
                    scale: parent.width / width
                    transformOrigin: Item.TopLeft

                    ShapePath {
                        fillColor: root.indicatorColor
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: "M320 880q-17 0-28.5-11.5T280 840v-640q0-17 11.5-28.5T320 160h80V80h160v80h80q17 0 28.5 11.5T680 200v640q0 17-11.5 28.5T640 880H320Z"
                        }
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
            text: root.available ? String(root.batteryPercent) : "--"
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
