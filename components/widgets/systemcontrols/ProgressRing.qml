import QtQuick

Canvas {
    id: root

    property int canvasPadding: 1
    property color indicatorColor: "transparent"
    property real progress: 0
    property real displayedProgress: 0
    readonly property real diameter: Math.max(0, Math.min(width, height) - canvasPadding * 2)

    onCanvasPaddingChanged: requestPaint()
    onDiameterChanged: requestPaint()
    onDisplayedProgressChanged: requestPaint()
    onHeightChanged: requestPaint()
    onIndicatorColorChanged: requestPaint()
    onProgressChanged: displayedProgress = Math.max(0, Math.min(1, progress))
    onWidthChanged: requestPaint()

    Behavior on displayedProgress {
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutQuad
        }
    }

    onPaint: {
        const context = getContext("2d");
        const lineWidth = Math.max(2, root.diameter * 0.1);
        const radius = Math.max(0, (root.diameter - lineWidth) / 2);
        const centerX = width / 2;
        const centerY = height / 2;
        const start = -Math.PI / 2;
        const end = start + Math.PI * 2 * root.displayedProgress;

        context.clearRect(0, 0, width, height);

        if (root.diameter <= 0)
            return;

        context.lineWidth = lineWidth;
        context.lineCap = "round";
        context.strokeStyle = Qt.rgba(root.indicatorColor.r, root.indicatorColor.g, root.indicatorColor.b, 0.24);
        context.beginPath();
        context.arc(centerX, centerY, radius, 0, Math.PI * 2);
        context.stroke();

        if (root.displayedProgress <= 0)
            return;

        context.strokeStyle = root.indicatorColor;
        context.beginPath();
        context.arc(centerX, centerY, radius, start, end);
        context.stroke();
    }

    Component.onCompleted: displayedProgress = Math.max(0, Math.min(1, progress))
}
