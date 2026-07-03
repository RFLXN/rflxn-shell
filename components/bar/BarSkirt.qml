import QtQuick
import "../../theme"

Canvas {
    id: root

    property bool mirrored: false
    property color fillColor: Colors.barBg

    implicitWidth: 23
    implicitHeight: 23

    function drawLeftSkirt(ctx) {
        ctx.fillStyle = root.fillColor;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(root.width, 0);

        ctx.save();
        ctx.translate(root.width, root.height);
        ctx.scale(root.width, root.height);
        ctx.arc(0, 0, 1, -Math.PI / 2, -Math.PI, true);
        ctx.restore();

        ctx.closePath();
        ctx.fill();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        if (mirrored) {
            ctx.save();
            ctx.translate(width, 0);
            ctx.scale(-1, 1);
            drawLeftSkirt(ctx);
            ctx.restore();
            return;
        }

        drawLeftSkirt(ctx);
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()
}
