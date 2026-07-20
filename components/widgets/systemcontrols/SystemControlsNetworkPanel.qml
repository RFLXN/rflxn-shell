import Quickshell.Networking
import QtQuick
import "../../../theme"
import "../../state"

Rectangle {
    id: root

    property bool detailsAcquired: false
    property bool pollingActive: false
    readonly property var nmDetailsByDevice: NetworkState.nmDetailsByDevice
    readonly property var devices: Networking.devices?.values ?? []
    readonly property string deviceFingerprint: buildDeviceFingerprint()
    readonly property var adapters: adapterList(deviceFingerprint, nmDetailsByDevice)

    signal headerIconClicked()

    width: parent?.width ?? 380
    height: content.implicitHeight + 24
    border.color: Colors.widgetBorder
    border.width: 1
    color: Colors.barBg
    radius: 12

    function adapterIconPath(device) {
        if (isTailscaleAdapter(device))
            return icons.vpnKey;

        if (device?.type === DeviceType.Wifi) {
            const network = connectedWifiNetwork(device);

            return network ? wifiIconPath(toWifiStrengthLevel(network.signalStrength ?? 0)) : icons.signalWifiOff;
        }

        return icons.conversionPath;
    }

    function adapterStatusLabel(device) {
        if (isTailscaleAdapter(device))
            return ipAddresses(device).length > 0 ? "Connected" : "Detected";

        if (deviceConnected(device))
            return "Connected";

        if (device?.state === ConnectionState.Connecting)
            return "Connecting";

        if (device?.state === ConnectionState.Disconnecting)
            return "Disconnecting";

        return "Disconnected";
    }

    function adapterStatusTone(device) {
        if (isTailscaleAdapter(device))
            return ipAddresses(device).length > 0 ? Colors.accent : Colors.textMuted;

        if (deviceConnected(device))
            return Networking.connectivity === NetworkConnectivity.Full ? Colors.accent : Colors.warning;

        if (device?.state === ConnectionState.Connecting)
            return Colors.warning;

        return Colors.textMuted;
    }

    function adapterTypeLabel(device) {
        if (isTailscaleAdapter(device))
            return "Tailscale";

        return device?.type === DeviceType.Wifi ? "Wi-Fi" : "Wired";
    }

    function adapterSortRank(device) {
        if (device?.type === DeviceType.Wired)
            return 0;

        if (device?.type === DeviceType.Wifi)
            return 1;

        if (isTailscaleAdapter(device))
            return 2;

        return 3;
    }

    function buildDeviceFingerprint() {
        const parts = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];

            if (!isPhysicalAdapter(device))
                continue;

            const network = connectedWifiNetwork(device);

            parts.push([
                String(device?.name ?? index),
                String(device?.address ?? ""),
                String(device?.type ?? ""),
                String(device?.connected ?? false),
                String(device?.state ?? ""),
                String(network?.name ?? ""),
                String(network?.signalStrength ?? "")
            ].join(":"));
        }

        return parts.join("|");
    }

    function connectedWifiNetwork(device) {
        if (!device || device.type !== DeviceType.Wifi)
            return null;

        const networks = device.networks?.values ?? [];

        for (const network of networks) {
            if (network?.connected || network?.state === ConnectionState.Connected)
                return network;
        }

        return null;
    }

    function colorToSvg(value) {
        const red = Math.round(value.r * 255);
        const green = Math.round(value.g * 255);
        const blue = Math.round(value.b * 255);

        return `rgb(${red},${green},${blue})`;
    }

    function deviceConnected(device) {
        if (!device)
            return false;

        if (isTailscaleAdapter(device))
            return ipAddresses(device).length > 0;

        if (device.connected || device.state === ConnectionState.Connected)
            return true;

        if (device.type === DeviceType.Wifi && Boolean(connectedWifiNetwork(device)))
            return true;

        return device.type === DeviceType.Wired && Boolean(device.network?.connected);
    }

    function deviceName(device) {
        const name = String(device?.name ?? "").trim();

        return name || "Unknown adapter";
    }

    function detailFor(device) {
        return root.nmDetailsByDevice[root.deviceName(device)] ?? {};
    }

    function hasInternet() {
        return Networking.connectivity === NetworkConnectivity.Full;
    }

    function ipAddresses(device) {
        const details = detailFor(device);
        const ip4 = Array.isArray(details.ip4) ? details.ip4 : [];
        const ip6 = Array.isArray(details.ip6) ? details.ip6 : [];
        const publicIp6 = [];

        for (const address of ip6) {
            const value = String(address ?? "").trim();

            if (value && !value.toLowerCase().startsWith("fe80:"))
                publicIp6.push(value);
        }

        const addresses = ip4.concat(publicIp6);

        return addresses.length > 0 ? addresses : ip6;
    }

    function ipAddressText(device) {
        const addresses = ipAddresses(device);

        return addresses.length > 0 ? addresses.join(", ") : "No IP address";
    }

    function isPhysicalAdapter(device) {
        if (!device)
            return false;

        if (device.type !== DeviceType.Wired && device.type !== DeviceType.Wifi)
            return false;

        const name = deviceName(device);

        if (name.length === 0 || name.startsWith("/") || name === "lo")
            return false;

        const nmType = String(detailFor(device).type ?? "").trim();

        if (nmType.length > 0 && nmType !== "ethernet" && nmType !== "wifi")
            return false;

        return true;
    }

    function isTailscaleAdapter(device) {
        const name = deviceName(device).toLowerCase();
        const type = String(detailFor(device).type ?? "").trim().toLowerCase();

        return Boolean(device?.isTailscale) || name.startsWith("tailscale") || (type === "tun" && name.includes("tailscale"));
    }

    function isTailscaleDetails(name, details) {
        const deviceName = String(name ?? "").trim().toLowerCase();
        const deviceType = String(details?.type ?? "").trim().toLowerCase();

        return deviceName.startsWith("tailscale") || (deviceType === "tun" && deviceName.includes("tailscale"));
    }

    function macAddressText(device) {
        const address = String(device?.address ?? "").trim();
        const details = detailFor(device);
        const fallback = String(details.mac ?? "").trim();

        if (!address && !fallback && isTailscaleAdapter(device))
            return "N/A";

        return address || fallback || "Unknown";
    }

    function adapterList(_fingerprint, _nmDetailsByDevice) {
        const next = [];
        const seenNames = {};

        for (const device of devices) {
            if (isPhysicalAdapter(device)) {
                next.push(device);
                seenNames[deviceName(device)] = true;
            }
        }

        for (const name of Object.keys(_nmDetailsByDevice ?? {})) {
            const details = _nmDetailsByDevice[name] ?? {};

            if (!isTailscaleDetails(name, details) || seenNames[name])
                continue;

            next.push({
                isTailscale: true,
                name
            });
            seenNames[name] = true;
        }

        next.sort((left, right) => {
            const leftRank = adapterSortRank(left);
            const rightRank = adapterSortRank(right);

            if (leftRank !== rightRank)
                return leftRank - rightRank;

            return deviceName(left).localeCompare(deviceName(right));
        });

        return next;
    }

    function syncDetailsRequest() {
        if (root.pollingActive === root.detailsAcquired)
            return;

        root.detailsAcquired = root.pollingActive;

        if (root.detailsAcquired) {
            NetworkState.acquireDetails();
        } else {
            NetworkState.releaseDetails();
        }
    }

    function statusDescription() {
        if (adapters.length === 0)
            return "No network adapters detected";

        let connectedCount = 0;

        for (const device of adapters) {
            if (deviceConnected(device))
                connectedCount += 1;
        }

        if (connectedCount === 0)
            return `${adapters.length} adapters - disconnected`;

        return `${connectedCount}/${adapters.length} connected - ${hasInternet() ? "internet available" : "no full internet"}`;
    }

    function statusLabel() {
        if (adapters.length === 0)
            return "No adapter";

        if (hasInternet())
            return "Online";

        for (const device of adapters) {
            if (deviceConnected(device))
                return "Limited";
        }

        return "Offline";
    }

    function statusTone() {
        if (adapters.length === 0)
            return Colors.textMuted;

        if (hasInternet())
            return Colors.accent;

        for (const device of adapters) {
            if (deviceConnected(device))
                return Colors.warning;
        }

        return Colors.textMuted;
    }

    function svgSource(path, color) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 -960 960 960"><path fill="${colorToSvg(color)}" d="${path}"/></svg>`;

        return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    }

    function toWifiStrengthLevel(strength) {
        if (strength >= 0.75)
            return 4;

        if (strength >= 0.50)
            return 3;

        if (strength >= 0.25)
            return 2;

        return 1;
    }

    function wifiApText(device) {
        const network = connectedWifiNetwork(device);
        const name = String(network?.name ?? "").trim();

        return name || "Not connected";
    }

    function wifiIconPath(strengthLevel) {
        if (strengthLevel === 4)
            return icons.signalWifi4Bar;

        if (strengthLevel === 3)
            return icons.networkWifi3Bar;

        if (strengthLevel === 2)
            return icons.networkWifi2Bar;

        return icons.networkWifi1Bar;
    }

    QtObject {
        id: icons

        readonly property string conversionPath: "M760-120q-39 0-70-22.5T647-200H440q-66 0-113-47t-47-113q0-66 47-113t113-47h80q33 0 56.5-23.5T600-600q0-33-23.5-56.5T520-680H313q-13 35-43.5 57.5T200-600q-50 0-85-35t-35-85q0-50 35-85t85-35q39 0 69.5 22.5T313-760h207q66 0 113 47t47 113q0 66-47 113t-113 47h-80q-33 0-56.5 23.5T360-360q0 33 23.5 56.5T440-280h207q13-35 43.5-57.5T760-360q50 0 85 35t35 85q0 50-35 85t-85 35ZM228.5-691.5Q240-703 240-720t-11.5-28.5Q217-760 200-760t-28.5 11.5Q160-737 160-720t11.5 28.5Q183-680 200-680t28.5-11.5Z"
        readonly property string networkWifi1Bar: "M480-120 0-600q96-98 220-149t260-51q137 0 261 51t219 149L480-120ZM361-353q25-18 55.5-28t63.5-10q33 0 63.5 10t55.5 28l245-245q-78-59-170.5-90.5T480-720q-101 0-193.5 31.5T116-598l245 245Z"
        readonly property string networkWifi2Bar: "M480-120 0-600q96-98 220-149t260-51q137 0 261 51t219 149L480-120ZM299-415q38-28 84-43.5t97-15.5q51 0 97 15.5t84 43.5l183-183q-78-59-170.5-90.5T480-720q-101 0-193.5 31.5T116-598l183 183Z"
        readonly property string networkWifi3Bar: "M480-120 0-600q96-98 220-149t260-51q137 0 261 51t219 149L480-120ZM232-482q53-38 116-59.5T480-563q69 0 132 21.5T728-482l116-116q-78-59-170.5-90.5T480-720q-101 0-193.5 31.5T116-598l116 116Z"
        readonly property string signalWifi4Bar: "M480-120 0-600q95-97 219.5-148.5T480-800q136 0 260.5 51.5T960-600L480-120Z"
        readonly property string signalWifiOff: "m717-357-57-57 184-184q-79-60-172-91t-192-31q-29 0-58 3t-58 8l-66-66q45-12 90-18.5t92-6.5q136 0 260.5 51.5T960-600L717-357ZM480-234l67-66-350-350q-21 11-41 24.5T116-598l364 364ZM819-28 604-244 480-120 0-600q32-32 66.5-59t72.5-49L27-820l57-57L876-85l-57 57ZM512-562Zm-140 87Z"
        readonly property string vpnKey: "M280-400q-33 0-56.5-23.5T200-480q0-33 23.5-56.5T280-560q33 0 56.5 23.5T360-480q0 33-23.5 56.5T280-400Zm0 160q-100 0-170-70T40-480q0-100 70-170t170-70q73 0 130.5 40T500-580h420v200h-80v120H640v-120H500q-32 62-89.5 101T280-240Zm0-80q56 0 98.5-34t56.5-86h285v120h40v-120h80v-40H435q-14-52-56.5-86T280-640q-66 0-113 47t-47 113q0 66 47 113t113 47Z"
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
                            source: root.svgSource(icons.conversionPath, Colors.accent)
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
                            source: root.svgSource(icons.conversionPath, Colors.textOnAccent)
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
                        font.family: Typography.textFamily
                        font.pixelSize: 14
                        font.weight: Font.ExtraBold
                        text: "Network"
                    }

                    Text {
                        width: parent.width
                        color: Colors.textMuted
                        elide: Text.ElideRight
                        font.family: Typography.textFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: root.statusDescription()
                    }
                }

                Rectangle {
                    id: statusPill

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(58, statusText.implicitWidth + 18)
                    height: 24
                    color: root.hasInternet() ? Colors.accentSoft : Colors.widgetBg
                    radius: height / 2

                    Text {
                        id: statusText

                        anchors.centerIn: parent
                        color: root.statusTone()
                        font.family: Typography.textFamily
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
            spacing: 10

            Text {
                width: parent.width
                color: Colors.textMuted
                font.family: Typography.textFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                leftPadding: 10
                text: "No adapters"
                visible: root.adapters.length === 0
            }

            Repeater {
                model: root.adapters

                Column {
                    required property int index
                    required property var modelData

                    width: parent.width
                    spacing: 7

                    Item {
                        width: parent.width
                        height: 24

                        Rectangle {
                            id: statusDot

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            color: root.adapterStatusTone(modelData)
                            radius: height / 2
                        }

                        Image {
                            id: adapterIcon

                            anchors.left: statusDot.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            asynchronous: true
                            mipmap: true
                            source: root.svgSource(root.adapterIconPath(modelData), Colors.textSecondary)
                            sourceSize.height: 18
                            sourceSize.width: 18
                        }

                        Rectangle {
                            id: statusTag

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: statusTagText.implicitWidth + 14
                            height: 20
                            color: Colors.widgetBgHover
                            radius: height / 2

                            Text {
                                id: statusTagText

                                anchors.centerIn: parent
                                color: root.adapterStatusTone(modelData)
                                font.family: Typography.textFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                text: root.adapterStatusLabel(modelData)
                            }
                        }

                        Text {
                            anchors.left: adapterIcon.right
                            anchors.leftMargin: 8
                            anchors.right: statusTag.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Colors.textPrimary
                            elide: Text.ElideRight
                            font.family: Typography.textFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            text: root.deviceName(modelData)
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 1
                        rowSpacing: 4

                        Row {
                            width: parent.width
                            height: 20
                            spacing: 7
                            visible: modelData.type === DeviceType.Wifi

                            Text {
                                width: 36
                                color: Colors.textMuted
                                font.family: Typography.textFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                horizontalAlignment: Text.AlignRight
                                text: "AP"
                            }

                            Text {
                                width: parent.width - 43
                                color: Colors.textSecondary
                                elide: Text.ElideRight
                                font.family: Typography.textFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                text: root.wifiApText(modelData)
                            }
                        }

                        Row {
                            width: parent.width
                            height: 20
                            spacing: 7
                            visible: root.isTailscaleAdapter(modelData)

                            Text {
                                width: 36
                                color: Colors.textMuted
                                font.family: Typography.textFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                horizontalAlignment: Text.AlignRight
                                text: "VPN"
                            }

                            Text {
                                width: parent.width - 43
                                color: Colors.textSecondary
                                elide: Text.ElideRight
                                font.family: Typography.textFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                text: "Tailscale"
                            }
                        }

                        Row {
                            width: parent.width
                            height: 20
                            spacing: 7

                            Text {
                                width: 36
                                color: Colors.textMuted
                                font.family: Typography.textFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                horizontalAlignment: Text.AlignRight
                                text: "IP"
                            }

                            Text {
                                width: parent.width - 43
                                color: Colors.textSecondary
                                elide: Text.ElideRight
                                font.family: Typography.textFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                text: root.ipAddressText(modelData)
                            }
                        }

                        Row {
                            width: parent.width
                            height: 20
                            spacing: 7
                            visible: !root.isTailscaleAdapter(modelData)

                            Text {
                                width: 36
                                color: Colors.textMuted
                                font.family: Typography.textFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                horizontalAlignment: Text.AlignRight
                                text: "MAC"
                            }

                            Text {
                                width: parent.width - 43
                                color: Colors.textSecondary
                                elide: Text.ElideRight
                                font.family: Typography.textFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                text: root.macAddressText(modelData)
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.separator
                        visible: index < root.adapters.length - 1
                    }
                }
            }
        }
    }

    onPollingActiveChanged: root.syncDetailsRequest()

    Component.onCompleted: root.syncDetailsRequest()

    Component.onDestruction: {
        if (root.detailsAcquired)
            NetworkState.releaseDetails();
    }
}
