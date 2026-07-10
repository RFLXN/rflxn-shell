import Quickshell.Services.Pipewire
import QtQuick
import "../../../theme"

Rectangle {
    id: root

    property bool inputSelectorOpen: false
    property bool outputSelectorOpen: false
    property int revision: 0
    readonly property var audioCandidateNodes: allAudioCandidateNodes(revision)
    readonly property var inputDevices: audioDevices("input", revision)
    readonly property var inputNode: Pipewire.defaultAudioSource
    readonly property var outputDevices: audioDevices("output", revision)
    readonly property var outputNode: Pipewire.defaultAudioSink
    readonly property var trackedAudioNodes: trackedAudioObjects(audioCandidateNodes, outputNode, inputNode)

    signal headerIconClicked()

    width: parent?.width ?? 380
    height: content.implicitHeight + 24
    border.color: Colors.widgetBorder
    border.width: 1
    color: Colors.barBg
    radius: 12

    function closeSelectors() {
        root.inputSelectorOpen = false;
        root.outputSelectorOpen = false;
    }

    function audioDevices(kind, _revision) {
        const values = Pipewire.nodes.values ?? [];
        const devices = [];

        for (const node of values) {
            if (!isAudioDevice(node, kind))
                continue;

            devices.push(node);
        }

        devices.sort((left, right) => deviceLabel(left).localeCompare(deviceLabel(right)));

        return devices;
    }

    function allAudioCandidateNodes(_revision) {
        const values = Pipewire.nodes.values ?? [];
        const devices = [];

        for (const node of values) {
            if (isAudioDevice(node, "output") || isAudioDevice(node, "input"))
                devices.push(node);
        }

        return devices;
    }

    function deviceLabel(device) {
        const description = String(device?.description ?? "").trim();
        const nickname = String(device?.nickname ?? "").trim();
        const name = String(device?.name ?? "").trim();

        return description || nickname || name || "Unknown device";
    }

    function hasFlag(node, flag) {
        return (Number(node?.type ?? 0) & Number(flag)) !== 0;
    }

    function isMonitorSource(node) {
        const name = String(node?.name ?? "");
        const description = String(node?.description ?? "");

        return name.endsWith(".monitor") || description.startsWith("Monitor of ");
    }

    function isAudioDevice(node, kind) {
        if (!node || !node.audio || node.isStream)
            return false;

        if (kind === "output")
            return hasFlag(node, PwNodeType.Sink);

        return hasFlag(node, PwNodeType.Source) && !isMonitorSource(node);
    }

    function refreshNodes() {
        revision += 1;
    }

    function outputStatusDescription() {
        if (!Pipewire.ready)
            return "Waiting for PipeWire";

        if (!outputNode || !outputNode.audio)
            return "No output devices";

        const label = deviceLabel(outputNode);

        if (outputNode.audio.muted)
            return `${label} - muted`;

        return `${label} - ${Math.round(Math.max(0, outputNode.audio.volume) * 100)}%`;
    }

    function trackedAudioObjects(candidates, output, input) {
        const nodes = [];

        function addNode(node) {
            if (!node)
                return;

            for (const existing of nodes) {
                if (Number(existing?.id ?? -1) === Number(node?.id ?? -2))
                    return;
            }

            nodes.push(node);
        }

        for (const candidate of candidates ?? [])
            addNode(candidate);

        addNode(output);
        addNode(input);

        return nodes;
    }

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
            id: statusRow

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
                    id: headerIconButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    color: headerIconMouseArea.containsMouse ? Colors.accent : Colors.accentSoft
                    radius: height / 2

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                            easing.type: Easing.InOutQuad
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: headerIconMouseArea.containsMouse ? Colors.textOnAccent : Colors.accent
                        font.family: Typography.iconFamily
                        font.pixelSize: 16
                        text: "\uf028"

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    MouseArea {
                        id: headerIconMouseArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.headerIconClicked()
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
                        text: "Volume"
                    }

                    Text {
                        width: parent.width
                        color: Colors.textMuted
                        elide: Text.ElideRight
                        font.family: Typography.textFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: root.outputStatusDescription()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.separator
        }

        AudioDeviceSection {
            width: parent.width
            currentNode: root.outputNode
            devices: root.outputDevices
            emptyText: "No output devices"
            icon: "\uf028"
            mutedIcon: "\uf026"
            selectorOpen: root.outputSelectorOpen
            title: "Output"
            unmutedIcon: "\uf028"
            onDeviceSelected: device => {
                Pipewire.preferredDefaultAudioSink = device;
                root.outputSelectorOpen = false;
            }
            onSelectorToggled: {
                root.outputSelectorOpen = !root.outputSelectorOpen;
                if (root.outputSelectorOpen)
                    root.inputSelectorOpen = false;
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.separator
        }

        AudioDeviceSection {
            width: parent.width
            currentNode: root.inputNode
            devices: root.inputDevices
            emptyText: "No input devices"
            icon: "\uf130"
            mutedIcon: "\uf131"
            selectorOpen: root.inputSelectorOpen
            title: "Input"
            unmutedIcon: "\uf130"
            onDeviceSelected: device => {
                Pipewire.preferredDefaultAudioSource = device;
                root.inputSelectorOpen = false;
            }
            onSelectorToggled: {
                root.inputSelectorOpen = !root.inputSelectorOpen;
                if (root.inputSelectorOpen)
                    root.outputSelectorOpen = false;
            }
        }
    }

    PwObjectTracker {
        objects: root.trackedAudioNodes
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged() {
            root.refreshNodes();
        }
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            root.refreshNodes();
        }

        function onDefaultAudioSourceChanged() {
            root.refreshNodes();
        }

        function onReadyChanged() {
            root.refreshNodes();
        }
    }
}
