pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../state"

Rectangle {
    id: root

    readonly property var folders: SyncthingState.folders
    readonly property int attentionCount: countAttentionFolders(folders)
    readonly property string syncIconPath: "M160-160v-80h110l-16-14q-52-46-73-105t-21-119q0-111 66.5-197.5T400-790v84q-72 26-116 88.5T240-478q0 45 17 87.5t53 78.5l10 10v-98h80v240H160Zm400-10v-84q72-26 116-88.5T720-482q0-45-17-87.5T650-648l-10-10v98h-80v-240h240v80H690l16 14q52 46 73 105t21 119q0 111-66.5 197.5T560-170Z"

    width: parent?.width ?? 380
    height: content.implicitHeight + 24
    border.color: Colors.widgetBorder
    border.width: 1
    color: Colors.barBg
    radius: 12

    function colorToSvg(value) {
        const red = Math.round(value.r * 255);
        const green = Math.round(value.g * 255);
        const blue = Math.round(value.b * 255);

        return `rgb(${red},${green},${blue})`;
    }

    function svgSource(path, color) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 -960 960 960"><path fill="${colorToSvg(color)}" d="${path}"/></svg>`;

        return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    }

    function formatCount(value) {
        return String(Math.max(0, Math.round(Number(value ?? 0)))).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    function formatBytes(value) {
        let bytes = Math.max(0, Number(value ?? 0));
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let unitIndex = 0;

        while (bytes >= 1024 && unitIndex < units.length - 1) {
            bytes /= 1024;
            unitIndex += 1;
        }

        const digits = unitIndex === 0 || bytes >= 100 ? 0 : (bytes >= 10 ? 1 : 2);

        return `${bytes.toFixed(digits)} ${units[unitIndex]}`;
    }

    function folderErrorCount(folder) {
        return Math.max(Number(folder?.errors ?? 0), Number(folder?.pullErrors ?? 0));
    }

    function folderStatusKind(folder) {
        if (folder?.paused)
            return "paused";

        const state = String(folder?.state ?? "").toLowerCase();
        const hasFatalError = state === "error" || String(folder?.error ?? "").length > 0 || String(folder?.watchError ?? "").length > 0;

        if (hasFatalError)
            return "error";

        if (!folder?.statusAvailable)
            return "unknown";

        if (root.folderErrorCount(folder) > 0)
            return "error";

        if (state === "starting")
            return "starting";

        if (state.includes("scan"))
            return "scanning";

        if (state.includes("clean"))
            return "cleaning";

        if (state.includes("sync"))
            return "syncing";

        if (Number(folder?.needTotalItems ?? 0) > 0)
            return "outOfSync";

        if (Number(folder?.receiveOnlyTotalItems ?? 0) > 0)
            return "localChanges";

        if (Number(folder?.deviceCount ?? 0) <= 1)
            return "unshared";

        return "upToDate";
    }

    function folderStatusLabel(folder) {
        const kind = root.folderStatusKind(folder);

        if (kind === "paused")
            return "Paused";

        if (kind === "unknown")
            return "Unknown";

        if (kind === "error")
            return "Attention";

        if (kind === "starting")
            return "Starting";

        if (kind === "scanning")
            return "Scanning";

        if (kind === "syncing")
            return "Syncing";

        if (kind === "cleaning")
            return "Cleaning";

        if (kind === "outOfSync")
            return "Out of sync";

        if (kind === "localChanges")
            return "Local changes";

        if (kind === "unshared")
            return "Unshared";

        return "Up to date";
    }

    function folderStatusTone(folder) {
        const kind = root.folderStatusKind(folder);

        if (kind === "error")
            return Colors.critical;

        if (kind === "starting" || kind === "scanning" || kind === "cleaning" || kind === "outOfSync" || kind === "localChanges")
            return Colors.warning;

        if (kind === "paused" || kind === "unknown" || kind === "unshared")
            return Colors.textMuted;

        return Colors.accent;
    }

    function folderStatusDescription(folder) {
        const kind = root.folderStatusKind(folder);
        const errorCount = root.folderErrorCount(folder);
        const needItems = Number(folder?.needTotalItems ?? 0);
        const needDeletes = Number(folder?.needDeletes ?? 0);
        const needBytes = Number(folder?.needBytes ?? 0);

        if (kind === "paused")
            return "Synchronization paused";

        if (kind === "unknown")
            return "Folder status is unavailable";

        if (kind === "error") {
            if (errorCount > 0)
                return `${root.formatCount(errorCount)} sync ${errorCount === 1 ? "error" : "errors"}`;

            if (String(folder?.watchError ?? ""))
                return "Folder watcher needs attention";

            return "Folder is unavailable";
        }

        if (kind === "starting")
            return "Starting folder synchronization";

        if (kind === "scanning")
            return "Scanning local changes";

        if (kind === "cleaning")
            return "Cleaning previous versions";

        if (kind === "syncing" || kind === "outOfSync") {
            if (needItems > 0 && needDeletes === needItems && needBytes <= 0)
                return `${root.formatCount(needItems)} ${needItems === 1 ? "delete" : "deletes"} remaining`;

            if (needItems > 0 && needBytes > 0)
                return `${root.formatCount(needItems)} ${needItems === 1 ? "item" : "items"} · ${root.formatBytes(needBytes)} remaining`;

            if (needItems > 0)
                return `${root.formatCount(needItems)} ${needItems === 1 ? "item" : "items"} remaining`;

            return "Synchronizing files";
        }

        if (kind === "localChanges") {
            const changes = Number(folder?.receiveOnlyTotalItems ?? 0);

            return `${root.formatCount(changes)} local ${changes === 1 ? "change" : "changes"}`;
        }

        if (kind === "unshared")
            return "Not shared with another device";

        const synchronizedBytes = Number(folder?.globalBytes ?? 0);

        return synchronizedBytes > 0 ? `${root.formatBytes(synchronizedBytes)} synchronized` : "Everything is synchronized";
    }

    function folderProgress(folder) {
        const kind = root.folderStatusKind(folder);
        const globalBytes = Number(folder?.globalBytes ?? 0);
        const inSyncBytes = Number(folder?.inSyncBytes ?? 0);
        const needBytes = Number(folder?.needBytes ?? 0);

        if ((kind !== "syncing" && kind !== "outOfSync") || globalBytes <= 0 || needBytes <= 0)
            return -1;

        return Math.max(0, Math.min(0.99, inSyncBytes / globalBytes));
    }

    function countAttentionFolders(items) {
        let count = 0;

        for (const folder of items ?? []) {
            const kind = root.folderStatusKind(folder);

            if (kind === "error" || kind === "outOfSync" || kind === "localChanges")
                count += 1;
        }

        return count;
    }

    function headerDescription() {
        if (SyncthingState.loading)
            return "Loading folder status";

        if (!SyncthingState.apiAvailable)
            return SyncthingState.lastError || "Folder status is unavailable";

        const count = root.folders.length;
        const folderLabel = count === 1 ? "1 folder" : `${count} folders`;

        return root.attentionCount > 0 ? `${folderLabel} · ${root.attentionCount} need attention` : folderLabel;
    }

    function headerStatusLabel() {
        if (SyncthingState.loading)
            return "Loading";

        return SyncthingState.apiAvailable ? "Running" : "API unavailable";
    }

    function headerStatusTone() {
        if (SyncthingState.loading)
            return Colors.warning;

        return SyncthingState.apiAvailable ? Colors.accent : Colors.critical;
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
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    color: Colors.accentSoft
                    radius: height / 2

                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        asynchronous: true
                        mipmap: true
                        source: root.svgSource(root.syncIconPath, Colors.accent)
                        sourceSize.height: 18
                        sourceSize.width: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44 - headerStatusPill.width - 10
                    spacing: 2

                    Text {
                        width: parent.width
                        color: Colors.textPrimary
                        font.family: Typography.textFamily
                        font.pixelSize: 14
                        font.weight: Font.ExtraBold
                        text: "Syncthing"
                    }

                    Text {
                        width: parent.width
                        color: SyncthingState.apiAvailable || SyncthingState.loading ? Colors.textMuted : Colors.critical
                        elide: Text.ElideRight
                        font.family: Typography.textFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: root.headerDescription()
                    }
                }

                Rectangle {
                    id: headerStatusPill

                    readonly property color tone: root.headerStatusTone()

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(56, headerStatusText.implicitWidth + 18)
                    height: 24
                    color: Qt.rgba(tone.r, tone.g, tone.b, 0.14)
                    radius: height / 2

                    Text {
                        id: headerStatusText

                        anchors.centerIn: parent
                        color: headerStatusPill.tone
                        font.family: Typography.textFamily
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        text: root.headerStatusLabel()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.separator
        }

        Item {
            readonly property bool shown: SyncthingState.loading || !SyncthingState.apiAvailable || root.folders.length === 0

            width: parent.width
            height: shown ? 38 : 0
            visible: shown

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 10
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                color: SyncthingState.apiAvailable || SyncthingState.loading ? Colors.textMuted : Colors.critical
                elide: Text.ElideRight
                font.family: Typography.textFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                text: SyncthingState.loading ? "Loading synchronized folders…" : (SyncthingState.apiAvailable ? "No synchronized folders" : (SyncthingState.lastError || "Syncthing API is unavailable"))
            }
        }

        Column {
            id: folderList

            readonly property bool shown: SyncthingState.apiAvailable && !SyncthingState.loading && root.folders.length > 0

            width: parent.width
            height: shown ? implicitHeight : 0
            visible: shown

            Repeater {
                model: root.folders

                Item {
                    id: folderRow

                    required property int index
                    required property var modelData

                    readonly property color tone: root.folderStatusTone(modelData)
                    readonly property string kind: root.folderStatusKind(modelData)
                    readonly property real progress: root.folderProgress(modelData)

                    width: folderList.width
                    height: rowContent.implicitHeight + 10 + (index > 0 ? 1 : 0)

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }

                        height: 1
                        color: Colors.separator
                        visible: folderRow.index > 0
                    }

                    Column {
                        id: rowContent

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            topMargin: 5 + (folderRow.index > 0 ? 1 : 0)
                        }

                        spacing: 5

                        Item {
                            width: parent.width
                            height: 24

                            Rectangle {
                                id: statusDot

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9
                                height: 9
                                color: folderRow.tone
                                radius: height / 2
                            }

                            Rectangle {
                                id: folderStatusPill

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: folderStatusText.implicitWidth + 14
                                height: 20
                                color: Qt.rgba(folderRow.tone.r, folderRow.tone.g, folderRow.tone.b, 0.12)
                                radius: height / 2

                                Text {
                                    id: folderStatusText

                                    anchors.centerIn: parent
                                    color: folderRow.tone
                                    font.family: Typography.textFamily
                                    font.pixelSize: 10
                                    font.weight: Font.ExtraBold
                                    text: root.folderStatusLabel(folderRow.modelData)
                                }
                            }

                            Text {
                                anchors {
                                    left: statusDot.right
                                    leftMargin: 8
                                    right: folderStatusPill.left
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }

                                color: Colors.textPrimary
                                elide: Text.ElideRight
                                font.family: Typography.textFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                text: folderRow.modelData.label
                            }
                        }

                        Text {
                            width: parent.width
                            color: folderRow.kind === "error" ? Colors.critical : Colors.textMuted
                            elide: Text.ElideRight
                            font.family: Typography.textFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            leftPadding: 17
                            text: root.folderStatusDescription(folderRow.modelData)
                        }

                        Item {
                            width: parent.width
                            height: visible ? 5 : 0
                            visible: folderRow.progress >= 0

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    leftMargin: 17
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                height: 4
                                color: Colors.widgetBgHover
                                radius: height / 2

                                Rectangle {
                                    width: parent.width * folderRow.progress
                                    height: parent.height
                                    color: Colors.accent
                                    radius: height / 2

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 220
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
