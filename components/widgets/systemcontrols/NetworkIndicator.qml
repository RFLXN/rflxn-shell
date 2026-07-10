import Quickshell.Networking
import QtQuick
import "../../../theme"
import "../../state"

Item {
    id: root

    property bool active: false
    property int iconPixelSize: Metrics.compactIconSize + 2
    readonly property var devices: Networking.devices?.values ?? []
    readonly property var wiredDevice: firstConnectedDevice(DeviceType.Wired)
    readonly property var wifiDevice: firstConnectedDevice(DeviceType.Wifi)
    readonly property var wifiNetwork: connectedWifiNetwork(wifiDevice)
    readonly property bool hasWiredAdapter: hasDeviceType(DeviceType.Wired)
    readonly property bool hasWifiAdapter: hasDeviceType(DeviceType.Wifi)
    readonly property bool hasAdapter: hasWiredAdapter || hasWifiAdapter
    readonly property string transport: wiredDevice ? "wired" : (wifiDevice || wifiNetwork ? "wifi" : "none")
    readonly property bool connected: transport !== "none"
    readonly property bool hasInternet: connected && Networking.connectivity === NetworkConnectivity.Full
    readonly property bool wiredWithoutInternet: transport === "wired" && !hasInternet
    readonly property bool wifiWithoutInternet: transport === "wifi" && !hasInternet
    readonly property int wifiStrengthLevel: toWifiStrengthLevel(wifiNetwork?.signalStrength ?? 0)
    readonly property string iconPath: currentIconPath()
    readonly property color indicatorColor: {
        if (!hasAdapter || !connected || wiredWithoutInternet)
            return Colors.critical;

        if (wifiWithoutInternet)
            return Colors.warning;

        return active ? Colors.textPrimary : Colors.textSecondary;
    }

    width: implicitWidth
    height: Metrics.widgetHeight
    implicitWidth: iconPixelSize
    implicitHeight: Metrics.widgetHeight

    function colorToSvg(value) {
        const red = Math.round(value.r * 255);
        const green = Math.round(value.g * 255);
        const blue = Math.round(value.b * 255);

        return `rgb(${red},${green},${blue})`;
    }

    function connectedWifiNetwork(device) {
        if (!device)
            return null;

        const networks = device.networks?.values ?? [];

        for (const network of networks) {
            if (network?.connected || network?.state === ConnectionState.Connected)
                return network;
        }

        return null;
    }

    function currentIconPath() {
        if (!hasAdapter)
            return icons.conversionPathOff;

        if (transport === "wired")
            return hasInternet ? icons.conversionPath : icons.conversionPathOff;

        if (transport === "wifi")
            return wifiIconPath(wifiStrengthLevel);

        if (hasWifiAdapter)
            return icons.signalWifiOff;

        return icons.conversionPathOff;
    }

    function deviceConnected(device) {
        if (!device)
            return false;

        if (device.connected || device.state === ConnectionState.Connected)
            return true;

        if (device.type === DeviceType.Wifi && Boolean(connectedWifiNetwork(device)))
            return true;

        return device.type === DeviceType.Wired && Boolean(device.network?.connected);
    }

    function firstConnectedDevice(type) {
        for (const device of devices) {
            if (device?.type === type && deviceConnected(device))
                return device;
        }

        return null;
    }

    function hasDeviceType(type) {
        for (const device of devices) {
            if (device?.type === type)
                return true;
        }

        return false;
    }

    function svgSource(path, color) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 -960 960 960"><path fill="${colorToSvg(color)}" d="${path}"/></svg>`;

        return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    }

    function toWifiStrengthLevel(strength) {
        if (strength >= 75)
            return 4;

        if (strength >= 50)
            return 3;

        if (strength >= 25)
            return 2;

        return 1;
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
        readonly property string conversionPathOff: "M818-28 26-820l57-57L875-85l-57 57ZM440-200q-66 0-113-47t-47-113q0-66 47-113t113-47l80 80h-80q-33 0-56.5 23.5T360-360q0 33 23.5 56.5T440-280h240l142 142q-14 8-29.5 13t-32.5 5q-39 0-70-22.5T647-200H440Zm433-1L721-353q9-3 18.5-5t20.5-2q50 0 85 35t35 85q0 11-2 20.5t-5 18.5ZM608-466l-59-59q23-9 37-29t14-46q0-33-23.5-56.5T520-680H394l-80-80h206q66 0 113 47t47 113q0 42-20 77t-52 57ZM200-600q-50 0-85-35t-35-85q0-32 16-59t42-43l164 164q-16 26-43 42t-59 16Z"
        readonly property string networkWifi1Bar: "M480-120 0-600q96-98 220-149t260-51q137 0 261 51t219 149L480-120ZM361-353q25-18 55.5-28t63.5-10q33 0 63.5 10t55.5 28l245-245q-78-59-170.5-90.5T480-720q-101 0-193.5 31.5T116-598l245 245Z"
        readonly property string networkWifi2Bar: "M480-120 0-600q96-98 220-149t260-51q137 0 261 51t219 149L480-120ZM299-415q38-28 84-43.5t97-15.5q51 0 97 15.5t84 43.5l183-183q-78-59-170.5-90.5T480-720q-101 0-193.5 31.5T116-598l183 183Z"
        readonly property string networkWifi3Bar: "M480-120 0-600q96-98 220-149t260-51q137 0 261 51t219 149L480-120ZM232-482q53-38 116-59.5T480-563q69 0 132 21.5T728-482l116-116q-78-59-170.5-90.5T480-720q-101 0-193.5 31.5T116-598l116 116Z"
        readonly property string signalWifi4Bar: "M480-120 0-600q95-97 219.5-148.5T480-800q136 0 260.5 51.5T960-600L480-120Z"
        readonly property string signalWifiOff: "m717-357-57-57 184-184q-79-60-172-91t-192-31q-29 0-58 3t-58 8l-66-66q45-12 90-18.5t92-6.5q136 0 260.5 51.5T960-600L717-357ZM480-234l67-66-350-350q-21 11-41 24.5T116-598l364 364ZM819-28 604-244 480-120 0-600q32-32 66.5-59t72.5-49L27-820l57-57L876-85l-57 57ZM512-562Zm-140 87Z"
    }

    Image {
        anchors.centerIn: parent
        width: root.iconPixelSize
        height: root.iconPixelSize
        asynchronous: true
        mipmap: true
        source: root.svgSource(root.iconPath, root.indicatorColor)
        sourceSize.width: root.iconPixelSize
        sourceSize.height: root.iconPixelSize
    }

    Component.onCompleted: NetworkState.ensureLoaded()
}
