import Quickshell.Bluetooth
import QtQuick
import QtQuick.Shapes
import "../../../theme"

Item {
    id: root

    property bool active: false
    property int iconPixelSize: Metrics.compactIconSize + 2
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null && adapter !== undefined
    readonly property bool adapterEnabled: available && adapter.enabled && adapter.state !== BluetoothAdapterState.Disabled && adapter.state !== BluetoothAdapterState.Blocked
    readonly property string deviceConnectionState: connectionFingerprint()
    readonly property bool connected: adapterEnabled && deviceConnectionState.indexOf(":true") >= 0
    readonly property color indicatorColor: connected ? Colors.accent : adapterEnabled ? active ? Colors.textPrimary : Colors.textSecondary : Colors.textMuted
    readonly property real indicatorOpacity: available ? adapterEnabled ? 1 : 0.52 : 0
    readonly property string iconPath: connected ? connectedPath : adapterEnabled ? enabledPath : disabledPath
    readonly property string connectedPath: "M440 880v-304L256 760l-56-56 224-224-224-224 56-56 184 184V80h40l228 228-172 172 172 172-228 228h-40Zm80-496 76-76-76-74v150Zm0 342 76-74-76-76v150ZM157.5 522.5Q140 505 140 480t17.5-42.5Q175 420 200 420t42.5 17.5Q260 455 260 480t-17.5 42.5Q225 540 200 540t-42.5-17.5Zm560 0Q700 505 700 480t17.5-42.5Q735 420 760 420t42.5 17.5Q820 455 820 480t-17.5 42.5Q785 540 760 540t-42.5-17.5Z"
    readonly property string disabledPath: "M792 904 624 736 480 880h-40V576L256 760l-56-56 196-196L56 168l56-56 736 736-56 56ZM520 726l46-46-46-46v92Zm44-274-56-56 88-88-76-74v174l-80-80V80h40l228 228-144 144Z"
    readonly property string enabledPath: "M440 880v-304L256 760l-56-56 224-224-224-224 56-56 184 184V80h40l228 228-172 172 172 172-228 228h-40Zm80-496 76-76-76-74v150Zm0 342 76-74-76-76v150Z"

    width: implicitWidth
    height: Metrics.widgetHeight
    implicitWidth: iconPixelSize
    implicitHeight: Metrics.widgetHeight
    visible: available
    opacity: indicatorOpacity

    function connectionFingerprint() {
        const devices = Bluetooth.devices?.values ?? [];
        const parts = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];

            parts.push(`${String(device?.address ?? index)}:${Boolean(device?.connected)}`);
        }

        return parts.join("|");
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        anchors.centerIn: parent
        width: root.iconPixelSize
        height: root.iconPixelSize

        Shape {
            width: 960
            height: 960
            preferredRendererType: Shape.CurveRenderer
            scale: parent.width / width
            transformOrigin: Item.TopLeft

            ShapePath {
                fillColor: root.indicatorColor
                strokeColor: "transparent"
                strokeWidth: 0

                PathSvg {
                    path: root.iconPath
                }
            }
        }
    }
}
