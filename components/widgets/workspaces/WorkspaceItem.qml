import Quickshell.Hyprland
import QtQml.Models
import QtQuick
import "../../../theme"

Rectangle {
    id: root

    property var workspace
    property var windows: []
    property bool animateWindowChanges: false
    property int itemSize: Metrics.widgetHeight
    property real urgentPulse: 0
    property bool useExternalFocusHighlight: false
    readonly property color urgentForeground: "#15110a"
    readonly property bool urgent: workspace?.urgent ?? false
    readonly property bool hasWindows: (windows?.length ?? 0) > 0
    readonly property bool hasVisualWindows: visualWindowModel.count > 0
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool externalFocusedHover: useExternalFocusHighlight && (workspace?.focused ?? false) && hovered
    readonly property color restingBackground: {
        if (urgent)
            return mixColor(Colors.widgetBg, Colors.warning, 0.24 + urgentPulse * 0.5);

        if (workspace?.focused && useExternalFocusHighlight)
            return "transparent";

        if (workspace?.focused)
            return Colors.widgetBgHover;

        if (hasVisualWindows)
            return Colors.widgetBg;

        return "transparent";
    }
    readonly property color restingBorder: {
        if (urgent)
            return mixColor(Colors.widgetBorder, Colors.warning, 0.38 + urgentPulse * 0.62);

        if (workspace?.focused && useExternalFocusHighlight)
            return "transparent";

        if (workspace?.focused || hasVisualWindows)
            return Colors.widgetBorder;

        return "transparent";
    }
    signal externalFocusedHoverStateChanged(bool active)

    width: Math.max(1, hasWindows ? windows.length : 1) * itemSize
    height: itemSize
    radius: height / 2
    color: hovered && !externalFocusedHover ? Colors.widgetBgActive : restingBackground
    border.width: 1
    border.color: hovered && !externalFocusedHover ? Colors.widgetBorder : restingBorder
    clip: false
    scale: urgent ? 1 + urgentPulse * 0.035 : 1
    transformOrigin: Item.Center

    function mixColor(from, to, amount) {
        const t = Math.max(0, Math.min(1, amount));

        return Qt.rgba(from.r + (to.r - from.r) * t, from.g + (to.g - from.g) * t, from.b + (to.b - from.b) * t, from.a + (to.a - from.a) * t);
    }

    function windowKey(window, index) {
        const address = String(window?.address ?? "");

        if (address.length > 0)
            return address;

        return `${String(window?.label ?? "")}:${String(window?.title ?? "")}:${index}`;
    }

    function visualWindowIndex(key) {
        for (let index = 0; index < visualWindowModel.count; index++) {
            if (String(visualWindowModel.get(index).windowKey ?? "") === key)
                return index;
        }

        return -1;
    }

    function windowEntry(window, index, entering, exiting) {
        return {
            windowAddress: String(window?.address ?? ""),
            windowEntering: entering,
            windowExiting: exiting,
            windowFocused: Boolean(window?.focused ?? false),
            windowIcon: String(window?.icon ?? ""),
            windowKey: windowKey(window, index),
            windowLabel: String(window?.label ?? ""),
            windowTitle: String(window?.title ?? "")
        };
    }

    function finishWindowExit(key) {
        const index = visualWindowIndex(key);

        if (index >= 0 && visualWindowModel.get(index).windowExiting)
            visualWindowModel.remove(index);
    }

    function syncVisualWindows(animate) {
        const nextKeys = [];
        const currentWindows = root.windows ?? [];

        for (let index = 0; index < currentWindows.length; index++) {
            const window = currentWindows[index];
            const key = windowKey(window, index);
            let existingIndex = visualWindowIndex(key);

            nextKeys.push(key);

            if (existingIndex < 0) {
                visualWindowModel.append(windowEntry(window, index, animate, false));
                continue;
            }

            visualWindowModel.set(existingIndex, windowEntry(window, index, false, false));
        }

        for (let index = visualWindowModel.count - 1; index >= 0; index--) {
            const entry = visualWindowModel.get(index);
            const key = String(entry.windowKey ?? "");

            if (!nextKeys.includes(key) && !entry.windowExiting) {
                visualWindowModel.setProperty(index, "windowEntering", false);
                visualWindowModel.setProperty(index, "windowExiting", true);
            }
        }
    }

    Behavior on color {
        enabled: !workspace?.urgent

        ColorAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on border.color {
        enabled: !workspace?.urgent

        ColorAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    Behavior on x {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: urgentPulseAnimation

        running: root.urgent
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "urgentPulse"
            to: 1
            duration: 400
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: root
            property: "urgentPulse"
            to: 0
            duration: 400
            easing.type: Easing.InOutQuad
        }
    }

    ListModel {
        id: visualWindowModel

        dynamicRoles: true
    }

    Row {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: visualWindowModel

            WorkspaceWindowIcon {
                required property string windowAddress
                required property bool windowEntering
                required property bool windowExiting
                required property bool windowFocused
                required property string windowIcon
                required property string windowKey
                required property string windowLabel
                required property string windowTitle

                entering: windowEntering
                exiting: windowExiting
                presenceKey: windowKey
                urgent: root.workspace?.urgent ?? false
                window: ({
                        address: windowAddress,
                        focused: windowFocused,
                        icon: windowIcon,
                        label: windowLabel,
                        title: windowTitle,
                        urgent: root.urgent
                    })

                onExitFinished: key => root.finishWindowExit(key)
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 999
        color: root.urgent ? root.mixColor(Colors.textMuted, root.urgentForeground, 0.45 + root.urgentPulse * 0.55) : Colors.textMuted
        visible: !root.hasVisualWindows
    }

    HoverHandler {
        id: hoverHandler

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: {
            if (root.hasWindows)
                return;

            Hyprland.dispatch(`workspace ${root.workspace.id}`);
        }
    }

    onWindowsChanged: root.syncVisualWindows(root.animateWindowChanges)

    onExternalFocusedHoverChanged: root.externalFocusedHoverStateChanged(externalFocusedHover)

    onUrgentChanged: {
        if (!root.urgent)
            root.urgentPulse = 0;
    }

    Component.onCompleted: {
        root.syncVisualWindows(false);
        root.animateWindowChanges = true;
    }
}
