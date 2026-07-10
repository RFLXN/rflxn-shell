pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Scope {
    id: root

    property int detailsConsumerCount: 0
    property var nmDetailsByDevice: ({})
    readonly property bool detailsRequested: detailsConsumerCount > 0

    function acquireDetails() {
        root.detailsConsumerCount += 1;

        if (root.detailsConsumerCount === 1)
            root.refreshDetails();
    }

    function ensureLoaded() {
        // Accessing the singleton is enough to start its shared timers.
    }

    function nmcliValue(value) {
        const text = String(value ?? "");
        let decoded = "";

        for (let index = 0; index < text.length; index++) {
            if (text[index] === "\\" && index + 1 < text.length) {
                decoded += text[index + 1];
                index += 1;
            } else {
                decoded += text[index];
            }
        }

        return decoded;
    }

    function releaseDetails() {
        root.detailsConsumerCount = Math.max(0, root.detailsConsumerCount - 1);
    }

    function parseNmcliDetails(text) {
        const detailsByDevice = {};
        let current = null;

        for (const rawLine of String(text ?? "").split("\n")) {
            const line = rawLine.trim();

            if (!line)
                continue;

            const separatorIndex = line.indexOf(":");

            if (separatorIndex < 0)
                continue;

            const key = line.slice(0, separatorIndex);
            const value = root.nmcliValue(line.slice(separatorIndex + 1).trim());

            if (key === "GENERAL.DEVICE") {
                current = {
                    type: "",
                    mac: "",
                    ip4: [],
                    ip6: []
                };
                detailsByDevice[value] = current;
                continue;
            }

            if (current === null)
                continue;

            if (key === "GENERAL.TYPE") {
                current.type = value;
            } else if (key === "GENERAL.HWADDR") {
                current.mac = value;
            } else if (key.startsWith("IP4.ADDRESS")) {
                if (value)
                    current.ip4.push(value);
            } else if (key.startsWith("IP6.ADDRESS")) {
                if (value)
                    current.ip6.push(value);
            }
        }

        return detailsByDevice;
    }

    function refreshConnectivity() {
        if (Networking.canCheckConnectivity)
            Networking.checkConnectivity();
    }

    function refreshDetails() {
        if (!root.detailsRequested || detailsProcess.running)
            return;

        detailsProcess.exec(["nmcli", "-t", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.HWADDR,IP4.ADDRESS,IP6.ADDRESS", "dev", "show"]);
    }

    Process {
        id: detailsProcess

        stdout: StdioCollector {
            id: detailsStdout
        }

        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0)
                root.nmDetailsByDevice = root.parseNmcliDetails(detailsStdout.text);
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.detailsRequested

        onTriggered: root.refreshDetails()
    }

    Timer {
        interval: 30000
        repeat: true
        running: Networking.canCheckConnectivity
        triggeredOnStart: true

        onTriggered: root.refreshConnectivity()
    }
}
