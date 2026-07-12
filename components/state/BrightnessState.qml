pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property bool internalDisplayPresent: false
    property bool internalDisplayActive: false
    property string internalDisplayName: ""
    property string internalDisplayDescription: ""

    property bool backlightDeviceFound: false
    property string deviceName: ""
    property int currentBrightness: 0
    property int maxBrightness: 0
    property int currentPercent: 0

    property int pendingPercent: -1
    property int inFlightPercent: -1
    property int writeTargetPercent: -1
    property string writeDeviceName: ""
    property string readDeviceName: ""

    property bool monitorRefreshPending: false
    property bool backlightRefreshPending: false
    property bool readRefreshPending: false
    property int pollingConsumerCount: 0
    property bool backlightFailureReported: false
    property bool lastSetSucceeded: true
    property string lastError: ""

    readonly property bool available: internalDisplayActive && backlightDeviceFound
    readonly property int percent: pendingPercent >= 0 ? pendingPercent : (inFlightPercent >= 0 ? inFlightPercent : currentPercent)
    readonly property bool pollingRequested: pollingConsumerCount > 0

    function acquirePolling() {
        root.pollingConsumerCount += 1;

        if (root.pollingConsumerCount === 1)
            root.refreshBrightness();
    }

    function releasePolling() {
        root.pollingConsumerCount = Math.max(0, root.pollingConsumerCount - 1);
    }

    function clampPercent(value) {
        const number = Number(value);

        if (!Number.isFinite(number))
            return 1;

        return Math.max(1, Math.min(100, Math.round(number)));
    }

    function isInternalOutputName(name) {
        return /^(eDP|LVDS|DSI)(-|$)/i.test(String(name ?? "").trim());
    }

    function parseInternalMonitor(text) {
        try {
            const monitors = JSON.parse(String(text ?? ""));

            if (!Array.isArray(monitors))
                throw new Error("Hyprland monitor response is not an array");

            const internalMonitors = [];

            for (const monitor of monitors) {
                if (root.isInternalOutputName(monitor?.name))
                    internalMonitors.push(monitor);
            }

            internalMonitors.sort((left, right) => {
                const leftDisabled = left?.disabled === true;
                const rightDisabled = right?.disabled === true;

                if (leftDisabled !== rightDisabled)
                    return leftDisabled ? 1 : -1;

                return String(left?.name ?? "").localeCompare(String(right?.name ?? ""));
            });

            if (internalMonitors.length === 0)
                return {
                    present: false,
                    active: false,
                    name: "",
                    description: ""
                };

            const monitor = internalMonitors[0];

            return {
                present: true,
                active: monitor?.disabled !== true,
                name: String(monitor?.name ?? "").trim(),
                description: String(monitor?.description ?? "").trim()
            };
        } catch (error) {
            console.warn("Failed to parse Hyprland monitors for brightness", error);
            return null;
        }
    }

    function clearBacklightState() {
        root.backlightDeviceFound = false;
        root.deviceName = "";
        root.currentBrightness = 0;
        root.maxBrightness = 0;
        root.currentPercent = 0;
        root.pendingPercent = -1;
        root.inFlightPercent = -1;
        root.readDeviceName = "";
    }

    function applyInternalMonitor(monitor) {
        const previousName = root.internalDisplayName;

        root.internalDisplayPresent = monitor.present;
        root.internalDisplayActive = monitor.active;
        root.internalDisplayName = monitor.name;
        root.internalDisplayDescription = monitor.description;

        if (!monitor.active) {
            root.clearBacklightState();
            root.backlightFailureReported = false;
            return;
        }

        if (previousName && previousName !== monitor.name)
            root.clearBacklightState();

        root.refreshBacklightDevices();
    }

    function scheduleDiscovery() {
        monitorDebounce.restart();
    }

    function refreshMonitors() {
        if (monitorProcess.running) {
            root.monitorRefreshPending = true;
            return;
        }

        root.monitorRefreshPending = false;
        monitorProcess.exec(["env", "hyprctl", "-j", "monitors", "all"]);
    }

    function isExternalBacklightDevice(name) {
        return String(name ?? "").toLowerCase().includes("ddcci");
    }

    function parseBacklightDevices(text) {
        const devices = [];

        for (const rawLine of String(text ?? "").split("\n")) {
            const line = rawLine.trim();

            if (!line)
                continue;

            const fields = line.split(",");

            if (fields.length < 5)
                continue;

            const name = fields[0].trim();
            const deviceClass = fields[1].trim();
            const current = Number(fields[2]);
            const max = Number(fields[4]);
            const reportedPercent = Number(fields[3].replace("%", ""));
            const type = String(fields[5] ?? "unknown").trim().toLowerCase();

            if (!name || deviceClass !== "backlight" || root.isExternalBacklightDevice(name))
                continue;

            if (!Number.isFinite(current) || !Number.isFinite(max) || max <= 0)
                continue;

            const percent = Number.isFinite(reportedPercent) ? reportedPercent : current / max * 100;

            devices.push({
                name,
                current: Math.max(0, Math.round(current)),
                max: Math.max(1, Math.round(max)),
                percent: root.clampPercent(percent),
                type
            });
        }

        devices.sort((left, right) => {
            const rankDifference = root.backlightTypeRank(left.type) - root.backlightTypeRank(right.type);

            return rankDifference !== 0 ? rankDifference : left.name.localeCompare(right.name);
        });
        return devices;
    }

    function backlightTypeRank(type) {
        if (type === "firmware")
            return 0;

        if (type === "platform")
            return 1;

        if (type === "raw")
            return 2;

        return 3;
    }

    function backlightDiscoveryCommand() {
        const script = [
            "set -o pipefail",
            "brightnessctl --machine-readable --list --class=backlight |",
            "while IFS=, read -r device class current percent max; do",
            "  type=unknown",
            "  type_file=\"/sys/class/backlight/$device/type\"",
            "  if [ -r \"$type_file\" ]; then",
            "    IFS= read -r type < \"$type_file\" || type=unknown",
            "  fi",
            "  printf '%s,%s,%s,%s,%s,%s\\n' \"$device\" \"$class\" \"$current\" \"$percent\" \"$max\" \"$type\"",
            "done"
        ].join("\n");

        return ["env", "bash", "-c", script];
    }

    function preferredBacklightDevice(devices) {
        for (const device of devices) {
            if (device.name === root.deviceName)
                return device;
        }

        return devices.length > 0 ? devices[0] : null;
    }

    function applyBacklightDevice(device) {
        if (!device) {
            root.clearBacklightState();
            return;
        }

        const deviceChanged = root.deviceName !== device.name;

        if (deviceChanged) {
            root.pendingPercent = -1;
            root.inFlightPercent = -1;
            root.lastSetSucceeded = true;
            root.lastError = "";
        }

        root.deviceName = device.name;
        root.currentBrightness = device.current;
        root.maxBrightness = device.max;
        root.currentPercent = device.percent;
        root.backlightDeviceFound = true;
        root.backlightFailureReported = false;
    }

    function refreshBacklightDevices() {
        if (!root.internalDisplayActive) {
            root.clearBacklightState();
            return;
        }

        if (backlightProcess.running) {
            root.backlightRefreshPending = true;
            return;
        }

        root.backlightRefreshPending = false;
        backlightProcess.exec(root.backlightDiscoveryCommand());
    }

    function refreshBrightness() {
        if (!root.available)
            return;

        if (brightnessReadProcess.running) {
            root.readRefreshPending = true;
            return;
        }

        if (brightnessWriteProcess.running || root.pendingPercent >= 0) {
            root.readRefreshPending = true;
            return;
        }

        root.readRefreshPending = false;
        root.readDeviceName = root.deviceName;
        brightnessReadProcess.exec([
            "env",
            "brightnessctl",
            "--machine-readable",
            "--class=backlight",
            "--device",
            root.readDeviceName,
            "info"
        ]);
    }

    function setPercent(value) {
        if (!root.available)
            return;

        root.pendingPercent = root.clampPercent(value);
        writeDebounce.restart();
    }

    function flushPendingWrite() {
        if (!root.available || root.pendingPercent < 0 || brightnessWriteProcess.running)
            return;

        root.writeTargetPercent = root.pendingPercent;
        root.writeDeviceName = root.deviceName;
        root.pendingPercent = -1;
        root.inFlightPercent = root.writeTargetPercent;

        brightnessWriteProcess.exec([
            "env",
            "brightnessctl",
            "--quiet",
            "--class=backlight",
            "--device",
            root.writeDeviceName,
            "--min-value=1%",
            "set",
            `${root.writeTargetPercent}%`
        ]);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = String(event?.name ?? "");

            if (name === "monitoradded" || name === "monitoraddedv2" || name === "monitorremoved" || name === "monitorremovedv2")
                root.scheduleDiscovery();
        }
    }

    Timer {
        id: monitorDebounce

        interval: 100
        repeat: false

        onTriggered: root.refreshMonitors()
    }

    Timer {
        id: monitorRetry

        interval: 3000
        repeat: false

        onTriggered: root.refreshMonitors()
    }

    Timer {
        id: writeDebounce

        interval: 75
        repeat: false

        onTriggered: root.flushPendingWrite()
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.available && root.pollingRequested

        onTriggered: root.refreshBrightness()
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.internalDisplayActive && !root.backlightDeviceFound && !backlightProcess.running

        onTriggered: root.refreshBacklightDevices()
    }

    Process {
        id: monitorProcess

        stdout: StdioCollector {
            id: monitorStdout
        }

        stderr: StdioCollector {
            id: monitorStderr
        }

        onExited: exitCode => {
            let succeeded = false;

            if (exitCode === 0) {
                const monitor = root.parseInternalMonitor(monitorStdout.text);

                if (monitor) {
                    root.applyInternalMonitor(monitor);
                    monitorRetry.stop();
                    succeeded = true;
                }
            }

            if (!succeeded) {
                console.warn("Failed to detect an internal display", exitCode, monitorStderr.text);
                monitorRetry.restart();
            }

            if (root.monitorRefreshPending) {
                monitorRetry.stop();
                monitorDebounce.stop();
                root.refreshMonitors();
            }
        }
    }

    Process {
        id: backlightProcess

        stdout: StdioCollector {
            id: backlightStdout
        }

        stderr: StdioCollector {
            id: backlightStderr
        }

        onExited: exitCode => {
            if (!root.internalDisplayActive) {
                root.backlightRefreshPending = false;
                root.clearBacklightState();
            } else if (exitCode === 0) {
                const devices = root.parseBacklightDevices(backlightStdout.text);

                root.applyBacklightDevice(root.preferredBacklightDevice(devices));
            } else {
                root.clearBacklightState();

                if (!root.backlightFailureReported) {
                    root.backlightFailureReported = true;
                    console.warn("No usable internal display backlight was found", backlightStderr.text);
                }
            }

            if (root.backlightRefreshPending && root.internalDisplayActive) {
                root.backlightRefreshPending = false;
                root.refreshBacklightDevices();
            }
        }
    }

    Process {
        id: brightnessReadProcess

        stdout: StdioCollector {
            id: brightnessReadStdout
        }

        stderr: StdioCollector {
            id: brightnessReadStderr
        }

        onExited: exitCode => {
            if (exitCode === 0 && root.readDeviceName === root.deviceName) {
                const devices = root.parseBacklightDevices(brightnessReadStdout.text);

                root.applyBacklightDevice(root.preferredBacklightDevice(devices));
            } else if (exitCode !== 0) {
                console.warn("Failed to read display brightness", brightnessReadStderr.text);
                root.refreshBacklightDevices();
            }

            root.readDeviceName = "";

            if (root.readRefreshPending) {
                root.readRefreshPending = false;
                root.refreshBrightness();
            }
        }
    }

    Process {
        id: brightnessWriteProcess

        stderr: StdioCollector {
            id: brightnessWriteStderr
        }

        onExited: exitCode => {
            const appliesToCurrentDevice = root.writeDeviceName && root.writeDeviceName === root.deviceName;

            if (exitCode === 0 && appliesToCurrentDevice) {
                root.currentPercent = root.writeTargetPercent;
                root.currentBrightness = Math.round(root.maxBrightness * root.currentPercent / 100);
                root.lastSetSucceeded = true;
                root.lastError = "";
            } else if (appliesToCurrentDevice) {
                root.lastSetSucceeded = false;
                root.lastError = String(brightnessWriteStderr.text ?? "").trim();
                console.warn("Failed to set display brightness", exitCode, root.lastError);
            }

            root.inFlightPercent = -1;
            root.writeTargetPercent = -1;
            root.writeDeviceName = "";

            if (root.pendingPercent >= 0 && root.available) {
                writeDebounce.restart();
            } else {
                root.refreshBrightness();
            }
        }
    }

    Component.onCompleted: root.scheduleDiscovery()
}
