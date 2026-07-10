import QtQuick
import "../../../theme"

Item {
    id: root

    property string value: ""
    property string currentText: value
    property string incomingText: value
    property int rollDirection: 1
    property real progress: 0
    property bool animating: false
    property color textColor: "white"
    property string fontFamily: Typography.textFamily
    property int fontPixelSize: 16
    property int fontWeight: Font.DemiBold
    property int duration: 420

    clip: true

    function animationDirection(previousValue, nextValue) {
        const previous = Number(previousValue);
        const next = Number(nextValue);

        if (!Number.isFinite(previous) || !Number.isFinite(next))
            return 1;

        const upwardDistance = (next - previous + 10) % 10;
        const downwardDistance = (previous - next + 10) % 10;

        return upwardDistance <= downwardDistance ? 1 : -1;
    }

    function finishRoll() {
        if (!root.animating)
            return;

        root.currentText = root.incomingText;
        root.progress = 0;
        root.animating = false;
    }

    function snapTo(value) {
        root.animating = false;
        rollAnimation.stop();
        root.currentText = value;
        root.incomingText = value;
        root.progress = 0;
    }

    function rollTo(nextValue) {
        const next = String(nextValue ?? "");

        if (next === root.currentText && !root.animating)
            return;

        if (root.currentText.length === 0 || next.length === 0) {
            root.snapTo(next);
            return;
        }

        if (rollAnimation.running) {
            root.animating = false;
            rollAnimation.stop();
            root.currentText = root.incomingText;
            root.progress = 0;
        }

        root.rollDirection = root.animationDirection(root.currentText, next);
        root.incomingText = next;
        root.progress = 0;
        root.animating = true;
        rollAnimation.restart();
    }

    onValueChanged: root.rollTo(value)

    Component.onCompleted: root.snapTo(root.value)

    Text {
        id: outgoingDigit

        width: parent.width
        height: parent.height
        y: root.animating ? -root.rollDirection * root.progress * root.height : 0
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        horizontalAlignment: Text.AlignHCenter
        opacity: root.animating ? 1 - root.progress * 0.18 : 1
        text: root.currentText
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        id: incomingDigit

        visible: root.animating
        width: parent.width
        height: parent.height
        y: root.rollDirection * (1 - root.progress) * root.height
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.74 + root.progress * 0.26
        text: root.incomingText
        verticalAlignment: Text.AlignVCenter
    }

    NumberAnimation {
        id: rollAnimation

        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.OutCubic

        onStopped: root.finishRoll()
    }
}
