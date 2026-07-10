import Quickshell
import Quickshell.Hyprland
import QtQml.Models
import QtQuick
import "../../state"
import "../../../theme"

Item {
    id: root

    property var screen
    property bool focusedHovering: false
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

    function workspaceItemsForSnapshot(snapshot) {
        try {
            const monitor = (snapshot.monitors ?? []).find(candidate => candidate.name === root.monitorName);

            if (!monitor)
                return [];

            const activeWorkspaceId = Number(monitor.activeWorkspace?.id ?? -1);
            const activeWindow = snapshot.activewindow ?? {};
            const focusedWorkspaceId = Number(activeWindow.workspace?.id ?? activeWorkspaceId);
            const focusedAddress = String(activeWindow.address ?? "");
            const clients = (snapshot.clients ?? []).filter(isVisibleClient).filter(client => Number(client.monitor) === Number(monitor.id));

            const items = (snapshot.workspaces ?? []).filter(isNormalWorkspace).filter(workspace => workspace.monitor === root.monitorName).sort((left, right) => Number(left.id) - Number(right.id)).map(workspace => {
                const focused = Number(workspace.id) === focusedWorkspaceId;
                const windows = clients.filter(client => Number(client.workspace?.id ?? -1) === Number(workspace.id)).map(client => ({
                            address: String(client.address ?? ""),
                            focused: String(client.address ?? "") === focusedAddress,
                            icon: clientIcon(client),
                            label: clientLabel(client),
                            title: String(client.title || client.class || ""),
                            urgent: HyprlandState.hasUrgentAddress(client.address) || client.urgent === true
                        }));
                const urgent = !focused && windows.some(window => window.urgent);

                return {
                    active: Number(workspace.id) === activeWorkspaceId,
                    focused,
                    id: Number(workspace.id),
                    name: String(workspace.name ?? workspace.id),
                    urgent,
                    windows
                };
            });

            return items;
        } catch (error) {
            console.error("Failed to build Hyprland workspace model", error);
            return root.workspaceItems;
        }
    }

    function syncSharedSnapshot() {
        root.syncWorkspaceModel(root.workspaceItemsForSnapshot(HyprlandState.snapshot));
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
        target: HyprlandState

        function onSnapshotChanged() {
            root.syncSharedSnapshot();
        }
    }

    onMonitorNameChanged: root.syncSharedSnapshot()

    Component.onCompleted: root.syncSharedSnapshot()
}
