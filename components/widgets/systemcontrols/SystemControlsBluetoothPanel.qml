import Quickshell.Bluetooth
import QtQuick
import "../../../theme"

Rectangle {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null && adapter !== undefined
    readonly property bool adapterBlocked: hasAdapter && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool adapterChanging: hasAdapter && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
    readonly property bool powered: hasAdapter && adapter.enabled && adapter.state !== BluetoothAdapterState.Disabled && !adapterBlocked
    readonly property string deviceFingerprint: buildDeviceFingerprint()
    readonly property var connectedDevices: connectedDeviceList(deviceFingerprint)
    readonly property string enabledPath: "M440 880v-304L256 760l-56-56 224-224-224-224 56-56 184 184V80h40l228 228-172 172 172 172-228 228h-40Zm80-496 76-76-76-74v150Zm0 342 76-74-76-76v150Z"

    signal headerIconClicked()

    width: parent?.width ?? 380
    height: content.implicitHeight + 24
    border.color: Colors.widgetBorder
    border.width: 1
    color: Colors.barBg
    radius: 12

    function adapterName() {
        const name = String(root.adapter?.name ?? "").trim();
        const id = String(root.adapter?.adapterId ?? "").trim();

        return name || id || "Bluetooth adapter";
    }

    function buildDeviceFingerprint() {
        const devices = Bluetooth.devices?.values ?? [];
        const parts = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];

            parts.push([
                String(device?.address ?? index),
                String(device?.name ?? ""),
                String(device?.deviceName ?? ""),
                String(device?.connected ?? false),
                String(device?.state ?? ""),
                String(device?.paired ?? false),
                String(device?.trusted ?? false),
                String(device?.blocked ?? false),
                String(device?.batteryAvailable ?? false),
                String(device?.battery ?? -1)
            ].join(":"));
        }

        return parts.join("|");
    }

    function connectedDeviceList(_fingerprint) {
        const devices = Bluetooth.devices?.values ?? [];
        const connected = [];

        for (const device of devices) {
            if (!device)
                continue;

            if (device.connected || device.state === BluetoothDeviceState.Connecting)
                connected.push(device);
        }

        connected.sort((left, right) => {
            const leftConnecting = left.state === BluetoothDeviceState.Connecting;
            const rightConnecting = right.state === BluetoothDeviceState.Connecting;

            if (leftConnecting !== rightConnecting)
                return leftConnecting ? -1 : 1;

            return deviceName(left).localeCompare(deviceName(right));
        });

        return connected;
    }

    function connectedCountLabel(count) {
        return count === 1 ? "1 connected device" : `${count} connected devices`;
    }

    function colorToSvg(value) {
        const red = Math.round(value.r * 255);
        const green = Math.round(value.g * 255);
        const blue = Math.round(value.b * 255);

        return `rgb(${red},${green},${blue})`;
    }

    function deviceName(device) {
        const name = String(device?.name ?? "").trim();
        const deviceName = String(device?.deviceName ?? "").trim();
        const address = String(device?.address ?? "").trim();

        return name || deviceName || address || "Unknown device";
    }

    function batteryPercent(device) {
        if (!device?.batteryAvailable)
            return -1;

        const value = Number(device.battery ?? -1);

        if (!Number.isFinite(value) || value < 0)
            return -1;

        return Math.round(Math.max(0, Math.min(100, value <= 1 ? value * 100 : value)));
    }

    function statusDescription() {
        if (!hasAdapter)
            return "No Bluetooth adapter detected";

        if (adapterBlocked)
            return "Bluetooth adapter is blocked";

        if (!powered)
            return "Bluetooth is powered off";

        if (adapterChanging)
            return BluetoothAdapterState.toString(adapter.state);

        return connectedCountLabel(connectedDevices.length);
    }

    function statusLabel() {
        if (!hasAdapter)
            return "No adapter";

        if (adapterBlocked)
            return "Blocked";

        if (adapterChanging)
            return BluetoothAdapterState.toString(adapter.state);

        return powered ? "On" : "Off";
    }

    function statusTone() {
        if (!hasAdapter || !powered || adapterBlocked)
            return Colors.textMuted;

        return connectedDevices.length > 0 ? Colors.accent : Colors.textSecondary;
    }

    function svgSource(path, color) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 960 960"><path fill="${colorToSvg(color)}" d="${path}"/></svg>`;

        return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    }

    function tagList(device) {
        const tags = [];
        const battery = batteryPercent(device);

        tags.push(device?.state === BluetoothDeviceState.Connecting ? "Connecting" : "Connected");

        if (battery >= 0)
            tags.push(`${battery}% battery`);

        if (device?.paired)
            tags.push("Paired");

        if (device?.trusted)
            tags.push("Trusted");

        if (device?.blocked)
            tags.push("Blocked");

        return tags;
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

                    Item {
                        anchors.centerIn: parent
                        height: 18
                        width: 18

                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            mipmap: true
                            opacity: headerIconMouseArea.containsMouse ? 0 : 1
                            source: root.svgSource(root.enabledPath, Colors.accent)
                            sourceSize.height: 18
                            sourceSize.width: 18

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            mipmap: true
                            opacity: headerIconMouseArea.containsMouse ? 1 : 0
                            source: root.svgSource(root.enabledPath, Colors.textOnAccent)
                            sourceSize.height: 18
                            sourceSize.width: 18

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.InOutQuad
                                }
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
                    width: parent.width - 44 - statusPill.width - 10
                    spacing: 2

                    Text {
                        width: parent.width
                        color: Colors.textPrimary
                        font.family: "Pretendard"
                        font.pixelSize: 14
                        font.weight: Font.ExtraBold
                        text: "Bluetooth"
                    }

                    Text {
                        width: parent.width
                        color: Colors.textMuted
                        elide: Text.ElideRight
                        font.family: "Pretendard"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: root.statusDescription()
                    }
                }

                Rectangle {
                    id: statusPill

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(42, statusText.implicitWidth + 18)
                    height: 24
                    color: root.powered && !root.adapterBlocked ? Colors.accentSoft : Colors.widgetBg
                    radius: height / 2

                    Text {
                        id: statusText

                        anchors.centerIn: parent
                        color: root.powered && !root.adapterBlocked ? Colors.accent : Colors.textMuted
                        font.family: "Pretendard"
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        text: root.statusLabel()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.separator
        }

        Column {
            width: parent.width
            spacing: 8

            Row {
                width: parent.width
                height: 20
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    color: Colors.textMuted
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    text: "\uf0c0"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.textMuted
                    font.family: "Pretendard"
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    text: "Connected devices"
                }
            }

            Text {
                width: parent.width
                color: Colors.textMuted
                font.family: "Pretendard"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                leftPadding: 10
                text: {
                    if (!root.hasAdapter)
                        return "No adapter";

                    if (!root.powered)
                        return "Bluetooth is off";

                    return "No connected devices";
                }
                visible: !root.hasAdapter || !root.powered || root.connectedDevices.length === 0
            }

            Repeater {
                model: root.powered ? root.connectedDevices : []

                Column {
                    required property var modelData

                    width: parent.width
                    spacing: 6

                    Row {
                        width: parent.width
                        height: 22
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            color: modelData.state === BluetoothDeviceState.Connecting ? Colors.warning : Colors.success
                            radius: height / 2
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 18
                            color: Colors.textPrimary
                            elide: Text.ElideRight
                            font.family: "Pretendard"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            text: root.deviceName(modelData)
                        }
                    }

                    Row {
                        x: 18
                        width: parent.width
                        height: 20
                        spacing: 5

                        Repeater {
                            model: root.tagList(modelData)

                            Rectangle {
                                required property string modelData

                                width: tagLabel.implicitWidth + 14
                                height: 20
                                color: Colors.widgetBgHover
                                radius: height / 2

                                Text {
                                    id: tagLabel

                                    anchors.centerIn: parent
                                    color: modelData === "Blocked" ? Colors.critical : Colors.textSecondary
                                    font.family: "Pretendard"
                                    font.pixelSize: 10
                                    font.weight: Font.ExtraBold
                                    text: modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
