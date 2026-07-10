pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property bool refreshPending: false
    property var urgentAddresses: ({})
    property var snapshot: ({
            monitors: [],
            workspaces: [],
            clients: [],
            activewindow: {}
        })
    readonly property var activeWindow: snapshot?.activewindow ?? ({})
    readonly property string activeWindowTitle: displayTitle(activeWindow)

    function displayTitle(window) {
        const title = String(window?.title ?? "").trim();

        if (title.length > 0)
            return title;

        return String(window?.class ?? "").trim();
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
            return;

        const next = copyUrgentAddresses();

        next[normalized] = true;
        setUrgentAddresses(next);
    }

    function isVisibleClient(client) {
        return client && client.mapped !== false && client.hidden !== true;
    }

    function updateUrgentAddresses(nextSnapshot) {
        const clients = (nextSnapshot.clients ?? []).filter(isVisibleClient);
        const activeAddresses = {};
        const focusedWorkspaceIds = {};
        const next = copyUrgentAddresses();
        const activeWindowWorkspaceId = nextSnapshot.activewindow?.workspace?.id;

        for (const client of clients) {
            const address = normalizeAddress(client.address);

            if (!address)
                continue;

            activeAddresses[address] = true;

            if (client.urgent === true)
                next[address] = true;
        }

        if (activeWindowWorkspaceId !== undefined && activeWindowWorkspaceId !== null) {
            focusedWorkspaceIds[String(Number(activeWindowWorkspaceId))] = true;
        } else {
            for (const monitor of nextSnapshot.monitors ?? []) {
                const workspaceId = monitor.activeWorkspace?.id;

                if (workspaceId !== undefined && workspaceId !== null)
                    focusedWorkspaceIds[String(Number(workspaceId))] = true;
            }
        }

        for (const client of clients) {
            const workspaceId = String(Number(client.workspace?.id ?? -1));

            if (focusedWorkspaceIds[workspaceId])
                delete next[normalizeAddress(client.address)];
        }

        for (const address of Object.keys(next)) {
            if (!activeAddresses[address])
                delete next[address];
        }

        setUrgentAddresses(next);
    }

    function parseSnapshot(text) {
        if (!text.trim())
            return null;

        try {
            const nextSnapshot = JSON.parse(text);

            if (!Array.isArray(nextSnapshot.monitors) || !Array.isArray(nextSnapshot.workspaces) || !Array.isArray(nextSnapshot.clients))
                throw new Error("Hyprland snapshot is missing a collection");

            if (!nextSnapshot.activewindow || typeof nextSnapshot.activewindow !== "object")
                nextSnapshot.activewindow = {};

            return nextSnapshot;
        } catch (error) {
            console.error("Failed to parse Hyprland snapshot", error);
            return null;
        }
    }

    function scheduleRefresh() {
        refreshDebounce.restart();
    }

    function queueRefresh() {
        if (snapshotProcess.running) {
            root.refreshPending = true;
            return;
        }

        root.refreshPending = false;
        snapshotProcess.exec(snapshotProcess.command);
    }

    Connections {
        target: Hyprland

        function onActiveToplevelChanged() {
            root.scheduleRefresh();
        }

        function onFocusedWorkspaceChanged() {
            root.scheduleRefresh();
        }

        function onRawEvent(event) {
            const name = event.name;

            if (name === "urgent")
                root.addUrgentAddress(root.eventAddress(event));

            if (name === "workspace" || name === "focusedmon" || name === "createworkspace" || name === "destroyworkspace" || name === "moveworkspace" || name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "activewindow" || name === "activewindowv2" || name === "windowtitle" || name === "windowtitlev2" || name === "urgent" || name === "changefloatingmode" || name === "fullscreen")
                root.scheduleRefresh();
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

        onExited: exitCode => {
            if (exitCode === 0) {
                const nextSnapshot = root.parseSnapshot(snapshotStdout.text);

                if (nextSnapshot) {
                    root.updateUrgentAddresses(nextSnapshot);
                    root.snapshot = nextSnapshot;
                }
            } else {
                console.error("Failed to fetch Hyprland snapshot", exitCode, snapshotStderr.text);
            }

            if (root.refreshPending) {
                refreshDebounce.stop();
                root.queueRefresh();
            }
        }
    }

    Component.onCompleted: root.queueRefresh()
}
