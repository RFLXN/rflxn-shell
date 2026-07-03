import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQml.Models
import QtQuick
import "../../../theme"

Item {
    id: root

    property var screen
    property bool refreshPending: false
    property bool focusedHovering: false
    property var urgentAddresses: ({})
    property var workspaceItems: []
    property int itemSize: Metrics.widgetHeight
    property int itemSpacing: Metrics.globalYSpacing
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property string monitorName: monitor?.name ?? ""
    readonly property int focusedIndex: workspaceItems.findIndex(workspace => workspace.focused)
    readonly property real focusedHighlightX: focusedIndex >= 0 ? workspaceItems.slice(0, focusedIndex).reduce((offset, workspace) => offset + workspaceWidth(workspace) + workspaceRow.spacing, 0) : 0
    readonly property real focusedHighlightWidth: focusedIndex >= 0 ? workspaceWidth(workspaceItems[focusedIndex]) : 0
    readonly property real contentWidth: workspaceItems.reduce((offset, workspace, index) => offset + workspaceWidth(workspace) + (index > 0 ? workspaceRow.spacing : 0), 0)

    width: implicitWidth
    height: implicitHeight
    implicitWidth: contentWidth
    implicitHeight: itemSize

    function workspaceWidth(workspace) {
        return Math.max(1, workspace?.windows?.length ?? 0) * itemSize;
    }

    function queueRefresh() {
        if (snapshotProcess.running) {
            root.refreshPending = true;
            return;
        }

        root.refreshPending = false;
        snapshotProcess.exec(snapshotProcess.command);
    }

    function isNormalWorkspace(workspace) {
        if (!workspace || workspace.id <= 0)
            return false;

        const name = String(workspace.name ?? "");

        return name !== "special" && !name.startsWith("special:");
    }

    function isVisibleClient(client) {
        return client && client.mapped !== false && client.hidden !== true;
    }

    function clientLabel(client) {
        return String(client.class || client.initialClass || client.title || "?");
    }

    function clientIcon(client) {
        const id = String(client.class || client.initialClass || "");
        const entry = DesktopEntries.heuristicLookup(id);

        return entry?.icon ?? "";
    }

    function normalizeAddress(address) {
        const text = String(address ?? "").trim().toLowerCase();
        const match = text.match(/(?:0x)?[0-9a-f]{8,}/);

        if (!match)
            return "";

        const value = match[0];

        return value.startsWith("0x") ? value : `0x${value}`;
    }

    function eventAddress(event) {
        const candidates = [event?.data, event?.value, event?.payload, event?.body, event?.args];

        for (const candidate of candidates) {
            if (Array.isArray(candidate)) {
                for (const value of candidate) {
                    const address = normalizeAddress(value);

                    if (address)
                        return address;
                }

                continue;
            }

            const address = normalizeAddress(candidate);

            if (address)
                return address;
        }

        return "";
    }

    function hasUrgentAddress(address) {
        return Boolean(root.urgentAddresses[normalizeAddress(address)]);
    }

    function urgentAddressMapsEqual(left, right) {
        const leftKeys = Object.keys(left).sort();
        const rightKeys = Object.keys(right).sort();

        if (leftKeys.length !== rightKeys.length)
            return false;

        for (let index = 0; index < leftKeys.length; index++) {
            if (leftKeys[index] !== rightKeys[index])
                return false;
        }

        return true;
    }

    function copyUrgentAddresses() {
        const next = {};

        for (const address of Object.keys(root.urgentAddresses))
            next[address] = true;

        return next;
    }

    function setUrgentAddresses(next) {
        if (!urgentAddressMapsEqual(root.urgentAddresses, next))
            root.urgentAddresses = next;
    }

    function addUrgentAddress(address) {
        const normalized = normalizeAddress(address);

        if (!normalized)
            return false;

        const next = copyUrgentAddresses();

        next[normalized] = true;
        setUrgentAddresses(next);

        return true;
    }

    function workspaceEntry(workspace) {
        return {
            workspaceActive: workspace.active,
            workspaceFocused: workspace.focused,
            workspaceId: workspace.id,
            workspaceName: workspace.name,
            workspaceUrgent: workspace.urgent,
            workspaceWindowsJson: JSON.stringify(workspace.windows ?? [])
        };
    }

    function parseWindowsJson(text) {
        try {
            return JSON.parse(text || "[]");
        } catch (error) {
            console.error("Failed to parse workspace windows", error);
            return [];
        }
    }

    function workspaceModelIndex(workspaceId) {
        for (let index = 0; index < workspaceModel.count; index++) {
            if (Number(workspaceModel.get(index).workspaceId) === Number(workspaceId))
                return index;
        }

        return -1;
    }

    function syncWorkspaceModel(nextItems) {
        const nextIds = nextItems.map(workspace => Number(workspace.id));

        for (let index = workspaceModel.count - 1; index >= 0; index--) {
            if (!nextIds.includes(Number(workspaceModel.get(index).workspaceId)))
                workspaceModel.remove(index);
        }

        for (let index = 0; index < nextItems.length; index++) {
            const workspace = nextItems[index];
            const existingIndex = workspaceModelIndex(workspace.id);
            const entry = workspaceEntry(workspace);

            if (existingIndex < 0) {
                workspaceModel.insert(index, entry);
                continue;
            }

            if (existingIndex !== index)
                workspaceModel.move(existingIndex, index, 1);

            workspaceModel.set(index, entry);
        }

        root.workspaceItems = nextItems;
    }

    function parseSnapshot(text) {
        if (!text.trim())
            return [];

        try {
            const snapshot = JSON.parse(text);
            const monitor = (snapshot.monitors ?? []).find(candidate => candidate.name === root.monitorName);

            if (!monitor)
                return [];

            const activeWorkspaceId = Number(monitor.activeWorkspace?.id ?? -1);
            const activeWindow = snapshot.activewindow ?? {};
            const focusedWorkspaceId = Number(activeWindow.workspace?.id ?? activeWorkspaceId);
            const focusedAddress = String(activeWindow.address ?? "");
            const activeAddresses = {};
            const nextUrgentAddresses = copyUrgentAddresses();
            const clients = (snapshot.clients ?? []).filter(isVisibleClient).filter(client => Number(client.monitor) === Number(monitor.id));

            for (const client of clients) {
                const address = normalizeAddress(client.address);

                if (!address)
                    continue;

                activeAddresses[address] = true;

                if (client.urgent === true)
                    nextUrgentAddresses[address] = true;
            }

            const items = (snapshot.workspaces ?? []).filter(isNormalWorkspace).filter(workspace => workspace.monitor === root.monitorName).sort((left, right) => Number(left.id) - Number(right.id)).map(workspace => {
                const focused = Number(workspace.id) === focusedWorkspaceId;
                const windows = clients.filter(client => Number(client.workspace?.id ?? -1) === Number(workspace.id)).map(client => ({
                            address: String(client.address ?? ""),
                            focused: String(client.address ?? "") === focusedAddress,
                            icon: clientIcon(client),
                            label: clientLabel(client),
                            title: String(client.title || client.class || ""),
                            urgent: hasUrgentAddress(client.address) || client.urgent === true
                        }));
                const urgent = !focused && windows.some(window => window.urgent);

                if (focused) {
                    for (const window of windows)
                        delete nextUrgentAddresses[normalizeAddress(window.address)];
                }

                return {
                    active: Number(workspace.id) === activeWorkspaceId,
                    focused,
                    id: Number(workspace.id),
                    name: String(workspace.name ?? workspace.id),
                    urgent,
                    windows
                };
            });

            for (const address of Object.keys(nextUrgentAddresses)) {
                if (!activeAddresses[address])
                    delete nextUrgentAddresses[address];
            }

            setUrgentAddresses(nextUrgentAddresses);

            return items;
        } catch (error) {
            console.error("Failed to parse Hyprland workspace snapshot", error);
            return root.workspaceItems;
        }
    }

    ListModel {
        id: workspaceModel

        dynamicRoles: true
    }

    Rectangle {
        id: focusedHighlight

        x: root.focusedHighlightX
        y: 0
        width: root.focusedHighlightWidth
        height: root.height
        radius: height / 2
        color: root.focusedHovering ? Colors.widgetBgActive : Colors.widgetBgHover
        opacity: root.focusedIndex >= 0 ? 1 : 0
        border.width: 1
        border.color: Colors.widgetBorder

        Behavior on color {
            ColorAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: 210
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 210
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: workspaceRow

        anchors.fill: parent
        spacing: root.itemSpacing

        Repeater {
            model: workspaceModel

            WorkspaceItem {
                required property bool workspaceActive
                required property bool workspaceFocused
                required property int workspaceId
                required property string workspaceName
                required property bool workspaceUrgent
                required property string workspaceWindowsJson

                useExternalFocusHighlight: true
                workspace: ({
                        active: workspaceActive,
                        focused: workspaceFocused,
                        id: workspaceId,
                        name: workspaceName,
                        urgent: workspaceUrgent
                    })
                windows: root.parseWindowsJson(workspaceWindowsJson)

                onExternalFocusedHoverStateChanged: active => root.focusedHovering = active
            }
        }
    }

    Connections {
        target: Hyprland

        function onActiveToplevelChanged() {
            root.queueRefresh();
        }

        function onFocusedWorkspaceChanged() {
            root.queueRefresh();
        }

        function onRawEvent(event) {
            const name = event.name;

            if (name === "urgent")
                root.addUrgentAddress(root.eventAddress(event));

            if (name === "workspace" || name === "focusedmon" || name === "createworkspace" || name === "destroyworkspace" || name === "moveworkspace" || name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "activewindow" || name === "urgent" || name === "changefloatingmode" || name === "fullscreen")
                refreshDebounce.restart();
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

        command: ["bash", "-lc", "printf '{\"monitors\":'; hyprctl -j monitors; printf ',\"workspaces\":'; hyprctl -j workspaces; printf ',\"clients\":'; hyprctl -j clients; printf ',\"activewindow\":'; hyprctl -j activewindow; printf '}'"]
        stderr: StdioCollector {
            id: snapshotStderr
        }
        stdout: StdioCollector {
            id: snapshotStdout
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.syncWorkspaceModel(root.parseSnapshot(snapshotStdout.text));
            } else {
                console.error("Failed to fetch Hyprland workspace snapshot", exitCode, snapshotStderr.text);
            }

            if (root.refreshPending)
                root.queueRefresh();
        }
    }

    Component.onCompleted: root.queueRefresh()
}
