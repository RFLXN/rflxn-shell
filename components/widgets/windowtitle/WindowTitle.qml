import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../../../theme"

Item {
    id: root

    property string title: ""
    property int visibleWidth: 480
    property int contentHeight: Metrics.widgetHeight
    property int scrollInterval: 16
    property real scrollSpeed: 32
    property int startPause: 1200
    property int endPause: 1600
    property real scrollOffset: 0
    property string scrollPhase: "start-pause"
    property int phaseElapsed: 0
    property string textFontFamily: "Pretendard"
    property int textFontPixelSize: 14
    property int textFontWeight: Font.Medium
    readonly property int textWidth: Math.ceil(titleMetrics.advanceWidth)
    readonly property int maxScroll: Math.max(0, textWidth - visibleWidth)
    readonly property bool scrollable: maxScroll > 1

    width: visibleWidth
    height: contentHeight
    clip: true
    opacity: title.length > 0 ? 1 : 0

    function displayTitle(window) {
        const title = String(window?.title ?? "").trim();

        if (title.length > 0)
            return title;

        return String(window?.class ?? "").trim();
    }

    function resetScroll() {
        scrollOffset = 0;
        scrollPhase = "start-pause";
        phaseElapsed = 0;
    }

    function queueRefresh() {
        if (snapshotProcess.running) {
            refreshDebounce.restart();
            return;
        }

        snapshotProcess.exec(snapshotProcess.command);
    }

    function updateScroll() {
        if (!scrollable) {
            resetScroll();
            scrollTimer.stop();
            return;
        }

        if (!scrollTimer.running)
            scrollTimer.restart();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: titleMetrics

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: root.title
    }

    Text {
        id: titleLabel

        x: root.scrollable ? -root.scrollOffset : 0
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.textPrimary
        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        height: parent.height
        horizontalAlignment: Text.AlignLeft
        text: root.title
        verticalAlignment: Text.AlignVCenter
        width: Math.max(root.visibleWidth, root.textWidth)
    }

    Timer {
        id: scrollTimer

        interval: root.scrollInterval
        repeat: true
        running: root.scrollable

        onTriggered: {
            if (!root.scrollable) {
                root.resetScroll();
                stop();
                return;
            }

            root.phaseElapsed += interval;

            if (root.scrollPhase === "start-pause") {
                root.scrollOffset = 0;

                if (root.phaseElapsed >= root.startPause) {
                    root.scrollPhase = "scrolling";
                    root.phaseElapsed = 0;
                }

                return;
            }

            if (root.scrollPhase === "end-pause") {
                root.scrollOffset = root.maxScroll;

                if (root.phaseElapsed >= root.endPause)
                    root.resetScroll();

                return;
            }

            root.scrollOffset = Math.min(root.maxScroll, root.scrollOffset + root.scrollSpeed * interval / 1000);

            if (root.scrollOffset >= root.maxScroll) {
                root.scrollPhase = "end-pause";
                root.phaseElapsed = 0;
            }
        }
    }

    Timer {
        id: refreshDebounce

        interval: 60
        repeat: false

        onTriggered: root.queueRefresh()
    }

    Process {
        id: snapshotProcess

        command: ["hyprctl", "-j", "activewindow"]
        stderr: StdioCollector {}
        stdout: StdioCollector {
            id: snapshotStdout
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                return;

            try {
                root.title = root.displayTitle(JSON.parse(snapshotStdout.text || "{}"));
            } catch (error) {
                console.error("Failed to parse Hyprland active window", error);
            }
        }
    }

    Connections {
        target: Hyprland

        function onActiveToplevelChanged() {
            refreshDebounce.restart();
        }

        function onRawEvent(event) {
            const name = event.name;

            if (name === "activewindow" || name === "activewindowv2" || name === "windowtitle" || name === "windowtitlev2" || name === "openwindow" || name === "closewindow")
                refreshDebounce.restart();
        }
    }

    onTitleChanged: {
        root.resetScroll();
        root.updateScroll();
    }

    onTextWidthChanged: root.updateScroll()

    Component.onCompleted: root.queueRefresh()
}
