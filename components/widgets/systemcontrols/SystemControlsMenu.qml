pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQuick
import "../../menu"
import "../../state"
import "../../../theme"

SideMenu {
    id: root

    // Temporary design preview. Set this to false to restore hardware-only visibility.
    readonly property bool brightnessPreviewEnabled: true
    readonly property bool brightnessAvailable: brightnessPreviewEnabled || BrightnessState.available
    readonly property var defaultPrograms: ({
            volume: {
                command: "pwvucontrol",
                rules: "float; size 900 650; center"
            },
            bluetooth: {
                command: "blueman-manager",
                rules: "float; size 760 560; center"
            },
            network: {
                command: "nm-connection-editor",
                rules: "float; size 880 640; center"
            }
        })
    property var programs: ({})
    property string confirmationAction: ""
    property string confirmationDisplayAction: ""
    property string lastPowerAction: ""
    signal panelResetRequested()

    menuId: "system-controls"
    menuWidth: 420
    direction: "right"

    onMenuOpenChanged: {
        if (menuOpen)
            return;

        clearConfirmationDisplayTimer.stop();
        root.confirmationAction = "";
        root.confirmationDisplayAction = "";
        root.panelResetRequested();
        panelFlickable.contentY = 0;
    }

    function actionConfirmLabel(action) {
        if (action === "shutdown")
            return "Power Off";

        if (action === "restart")
            return "Restart";

        return "Log Out";
    }

    function actionDescription(action) {
        if (action === "shutdown")
            return "Shut down this computer and end the current session.";

        if (action === "restart")
            return "Restart this computer and end the current session.";

        return "Log out of the current Hyprland session.";
    }

    function actionIconPath(action) {
        if (action === "shutdown")
            return icons.power;

        if (action === "restart")
            return icons.restart;

        return icons.logout;
    }

    function actionLabel(action) {
        if (action === "shutdown")
            return "Power Off";

        if (action === "restart")
            return "Restart";

        return "Logout";
    }

    function actionTone(action) {
        if (action === "shutdown")
            return Colors.critical;

        if (action === "restart")
            return Colors.warning;

        return Colors.accent;
    }

    function colorToSvg(value) {
        const red = Math.round(value.r * 255);
        const green = Math.round(value.g * 255);
        const blue = Math.round(value.b * 255);

        return `rgb(${red},${green},${blue})`;
    }

    function commandForPowerAction(action) {
        if (action === "shutdown")
            return ["sh", "-c", "exec systemctl poweroff"];

        if (action === "restart")
            return ["sh", "-c", "exec systemctl reboot"];

        const script = [
            "if command -v uwsm >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then",
            "  uwsm stop || hyprctl dispatch exit",
            "  exit 0",
            "fi",
            "if command -v uwsm >/dev/null 2>&1; then",
            "  exec uwsm stop",
            "fi",
            "if command -v hyprctl >/dev/null 2>&1; then",
            "  exec hyprctl dispatch exit",
            "fi",
            "exit 127"
        ].join("\n");

        return ["sh", "-c", script];
    }

    function confirmPowerAction() {
        const action = root.confirmationAction || root.confirmationDisplayAction;

        if (!action || powerActionProcess.running)
            return;

        root.lastPowerAction = action;
        root.confirmationAction = "";
        GlobalMenu.closeActiveMenu();
        powerActionProcess.exec(commandForPowerAction(action));
    }

    function closePowerConfirmation() {
        if (!root.confirmationAction)
            return;

        root.confirmationAction = "";
        clearConfirmationDisplayTimer.restart();
    }

    function footerButtonBackground(action, hovered) {
        if (!hovered)
            return "transparent";

        if (action === "shutdown")
            return Qt.rgba(Colors.critical.r, Colors.critical.g, Colors.critical.b, 0.16);

        if (action === "restart")
            return Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.16);

        return Colors.widgetBgHover;
    }

    function openPowerConfirmation(action) {
        const nextAction = String(action ?? "");

        if (!nextAction)
            return;

        clearConfirmationDisplayTimer.stop();
        root.confirmationDisplayAction = nextAction;
        root.confirmationAction = nextAction;
    }

    function svgSource(path, color) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 -960 960 960"><path fill="${colorToSvg(color)}" d="${path}"/></svg>`;

        return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    }

    function hasOwnValue(record, key) {
        return typeof record === "object" && record !== null && Object.prototype.hasOwnProperty.call(record, key);
    }

    function isNonEmptyString(value) {
        return typeof value === "string" && value.trim().length > 0;
    }

    function normalizedRules(value) {
        if (Array.isArray(value)) {
            const rules = [];

            for (const rule of value) {
                const text = String(rule ?? "").trim();

                if (text)
                    rules.push(text);
            }

            return rules.join("; ");
        }

        return isNonEmptyString(value) ? value.trim() : "";
    }

    function launchArgsFor(panelId) {
        const configured = hasOwnValue(root.programs, panelId) ? root.programs[panelId] : root.defaultPrograms[panelId];

        if (configured === null || configured === false)
            return null;

        if (Array.isArray(configured)) {
            const argv = [];

            for (const value of configured) {
                const arg = String(value ?? "").trim();

                if (arg)
                    argv.push(arg);
            }

            return argv.length > 0 ? {
                mode: "argv",
                args: argv,
                rules: ""
            } : null;
        }

        if (isNonEmptyString(configured))
            return {
                mode: "shell",
                args: [configured.trim()],
                rules: ""
            };

        if (typeof configured === "object" && configured !== null) {
            const rules = normalizedRules(configured.rules);

            if (Array.isArray(configured.argv)) {
                const argv = [];

                for (const value of configured.argv) {
                    const arg = String(value ?? "").trim();

                    if (arg)
                        argv.push(arg);
                }

                return argv.length > 0 ? {
                    mode: "argv",
                    args: argv,
                    rules
                } : null;
            }

            const command = isNonEmptyString(configured.command) ? configured.command : configured.program;

            if (isNonEmptyString(command))
                return {
                    mode: "shell",
                    args: [command.trim()],
                    rules
                };
        }

        return null;
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function commandTextFor(spec) {
        if (spec.mode === "shell")
            return String(spec.args[0] ?? "").trim();

        const argv = [];

        for (const arg of spec.args ?? [])
            argv.push(shellQuote(arg));

        return argv.join(" ");
    }

    function launchCommand(spec) {
        const rules = normalizedRules(spec.rules);
        const commandText = commandTextFor(spec);

        if (rules) {
            const script = [
                "rules=\"$1\"",
                "command_text=\"$2\"",
                "if [ -z \"$command_text\" ]; then",
                "  exit 127",
                "fi",
                "if command -v hyprctl >/dev/null 2>&1; then",
                "  hyprctl dispatch exec \"[$rules] $command_text\" && exit 0",
                "fi",
                "if command -v systemd-run >/dev/null 2>&1; then",
                "  exec systemd-run --user --collect --quiet --slice=app-graphical.slice -- sh -lc \"$command_text\"",
                "fi",
                "nohup sh -lc \"$command_text\" >/dev/null 2>&1 &",
                "exit 0"
            ].join("\n");

            return ["sh", "-c", script, "system-control-menu", rules, commandText];
        }

        const script = [
            "mode=\"$1\"",
            "shift",
            "if [ \"$#\" -eq 0 ]; then",
            "  exit 127",
            "fi",
            "if [ \"$mode\" = shell ]; then",
            "  command_text=\"$1\"",
            "  if command -v systemd-run >/dev/null 2>&1; then",
            "    exec systemd-run --user --collect --quiet --slice=app-graphical.slice -- sh -lc \"$command_text\"",
            "  fi",
            "  nohup sh -lc \"$command_text\" >/dev/null 2>&1 &",
            "  exit 0",
            "fi",
            "if command -v systemd-run >/dev/null 2>&1; then",
            "  exec systemd-run --user --collect --quiet --slice=app-graphical.slice -- \"$@\"",
            "fi",
            "nohup \"$@\" >/dev/null 2>&1 &",
            "exit 0"
        ].join("\n");

        return ["sh", "-c", script, "system-control-menu", spec.mode].concat(spec.args);
    }

    function launchPanelProgram(panelId) {
        if (programLaunchProcess.running)
            return false;

        const spec = launchArgsFor(panelId);

        if (spec === null)
            return false;

        programLaunchProcess.exec(launchCommand(spec));
        GlobalMenu.closeActiveMenu();

        return true;
    }

    Process {
        id: programLaunchProcess
    }

    Process {
        id: powerActionProcess

        onExited: exitCode => {
            if (exitCode !== 0)
                console.error(`Failed to execute ${root.lastPowerAction || "power action"}`, exitCode);
        }
    }

    Timer {
        id: clearConfirmationDisplayTimer

        interval: 140
        repeat: false

        onTriggered: {
            if (!root.confirmationAction)
                root.confirmationDisplayAction = "";
        }
    }

    QtObject {
        id: icons

        readonly property string logout: "M200-120q-33 0-56.5-23.5T120-200v-560q0-33 23.5-56.5T200-840h280v80H200v560h280v80H200Zm440-160-55-58 102-102H360v-80h327L585-622l55-58 200 200-200 200Z"
        readonly property string power: "M440-440v-400h80v400h-80Zm40 320q-74 0-139.5-28.5T226-226q-49-49-77.5-114.5T120-480q0-80 33-151t93-123l56 56q-48 39-75 95t-27 123q0 116 82 198t198 82q116 0 198-82t82-198q0-67-27-123t-75-95l56-56q60 52 93 123t33 151q0 74-28.5 139.5T734-226q-49 49-114.5 77.5T480-120Z"
        readonly property string restart: "M480-80q-75 0-140.5-28.5t-114-77q-48.5-48.5-77-114T120-440h80q0 117 81.5 198.5T480-160q117 0 198.5-81.5T760-440q0-117-81.5-198.5T480-720h-6l62 62-56 58-160-160 160-160 56 58-62 62h6q75 0 140.5 28.5t114 77q48.5 48.5 77 114T840-440q0 75-28.5 140.5t-77 114q-48.5 48.5-114 77T480-80Z"
    }

    Item {
        anchors.fill: parent

        Flickable {
            id: panelFlickable

            anchors {
                bottom: footer.top
                bottomMargin: 10
                left: parent.left
                right: parent.right
                top: parent.top
            }

            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: panelColumn.implicitHeight + 2
            contentWidth: width

            Column {
                id: panelColumn

                width: panelFlickable.width
                y: 2
                spacing: 10

                Loader {
                    id: volumePanelLoader

                    active: root.mounted
                    width: parent.width
                    sourceComponent: Component {
                        SystemControlsVolumePanel {
                            id: loadedVolumePanel

                            width: volumePanelLoader.width
                            onHeaderIconClicked: root.launchPanelProgram("volume")

                            Connections {
                                target: root

                                function onPanelResetRequested() {
                                    loadedVolumePanel.closeSelectors();
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: brightnessPanelLoader

                    active: root.mounted && root.brightnessAvailable
                    width: parent.width
                    sourceComponent: Component {
                        SystemControlsBrightnessPanel {
                            width: brightnessPanelLoader.width
                            pollingActive: root.menuOpen
                            previewMode: root.brightnessPreviewEnabled && !BrightnessState.available
                        }
                    }
                }

                Loader {
                    id: networkPanelLoader

                    active: root.mounted
                    width: parent.width
                    sourceComponent: Component {
                        SystemControlsNetworkPanel {
                            width: networkPanelLoader.width
                            pollingActive: root.menuOpen
                            onHeaderIconClicked: root.launchPanelProgram("network")
                        }
                    }
                }

                Loader {
                    id: bluetoothPanelLoader

                    active: root.mounted
                    width: parent.width
                    sourceComponent: Component {
                        SystemControlsBluetoothPanel {
                            width: bluetoothPanelLoader.width
                            onHeaderIconClicked: root.launchPanelProgram("bluetooth")
                        }
                    }
                }
            }
        }

        Rectangle {
            id: footer

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }

            height: 47
            color: "transparent"

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }

                height: 1
                color: Colors.separator
            }

            Row {
                id: footerButtons

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 8
                }

                spacing: 6

                Repeater {
                    model: ["logout", "restart", "shutdown"]

                    Rectangle {
                        id: footerButton

                        required property string modelData

                        anchors.verticalCenter: parent.verticalCenter
                        width: (footerButtons.width - footerButtons.spacing * 2) / 3
                        height: 34
                        color: root.footerButtonBackground(footerButton.modelData, footerMouseArea.containsMouse)
                        radius: 8

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                                easing.type: Easing.InOutQuad
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16

                                Image {
                                    anchors.fill: parent
                                    asynchronous: true
                                    mipmap: true
                                    opacity: footerMouseArea.containsMouse ? 0 : 1
                                    source: root.svgSource(root.actionIconPath(footerButton.modelData), Colors.textSecondary)
                                    sourceSize.height: 16
                                    sourceSize.width: 16

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
                                    opacity: footerMouseArea.containsMouse ? 1 : 0
                                    source: root.svgSource(root.actionIconPath(footerButton.modelData), root.actionTone(footerButton.modelData))
                                    sourceSize.height: 16
                                    sourceSize.width: 16

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                color: footerMouseArea.containsMouse ? root.actionTone(footerButton.modelData) : Colors.textSecondary
                                elide: Text.ElideRight
                                font.family: Typography.textFamily
                                font.pixelSize: 11
                                font.weight: Font.ExtraBold
                                text: root.actionLabel(footerButton.modelData)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: footerMouseArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: root.openPowerConfirmation(footerButton.modelData)
                        }
                    }
                }
            }
        }
    }

    Item {
        id: confirmationOverlay

        parent: root.overlayContainer
        anchors.fill: parent
        opacity: root.confirmationAction ? 1 : 0
        visible: opacity > 0
        z: 20

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(4 / 255, 8 / 255, 10 / 255, 0.68)

            MouseArea {
                anchors.fill: parent
                onClicked: root.closePowerConfirmation()
            }
        }

        Rectangle {
            id: confirmationCard

            anchors.centerIn: parent
            width: Math.min(380, Math.max(0, parent.width - 48))
            height: confirmationContent.implicitHeight + 52
            border.color: Colors.widgetBorder
            border.width: 1
            color: Colors.widgetBg
            radius: 24

            Column {
                id: confirmationContent

                anchors {
                    left: parent.left
                    leftMargin: 24
                    right: parent.right
                    rightMargin: 24
                    verticalCenter: parent.verticalCenter
                }

                spacing: 16

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: 72
                    color: Colors.barBg
                    radius: height / 2

                    Image {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        asynchronous: true
                        mipmap: true
                        source: root.svgSource(root.actionIconPath(root.confirmationDisplayAction), root.actionTone(root.confirmationDisplayAction))
                        sourceSize.height: 34
                        sourceSize.width: 34
                    }
                }

                Text {
                    width: parent.width
                    color: Colors.textPrimary
                    font.family: Typography.textFamily
                    font.pixelSize: 21
                    font.weight: Font.Black
                    horizontalAlignment: Text.AlignHCenter
                    text: root.actionConfirmLabel(root.confirmationDisplayAction)
                }

                Text {
                    width: parent.width
                    color: Colors.textSecondary
                    font.family: Typography.textFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.15
                    text: root.actionDescription(root.confirmationDisplayAction)
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Rectangle {
                        width: 118
                        height: 38
                        color: cancelMouseArea.containsMouse ? Colors.widgetBgActive : Colors.widgetBgHover
                        radius: 8

                        Text {
                            anchors.centerIn: parent
                            color: cancelMouseArea.containsMouse ? Colors.textPrimary : Colors.textSecondary
                            font.family: Typography.textFamily
                            font.pixelSize: 12
                            font.weight: Font.ExtraBold
                            text: "Cancel"
                        }

                        MouseArea {
                            id: cancelMouseArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: root.closePowerConfirmation()
                        }
                    }

                    Rectangle {
                        width: 118
                        height: 38
                        color: confirmMouseArea.containsMouse ? root.actionTone(root.confirmationDisplayAction) : Qt.rgba(root.actionTone(root.confirmationDisplayAction).r, root.actionTone(root.confirmationDisplayAction).g, root.actionTone(root.confirmationDisplayAction).b, 0.2)
                        radius: 8

                        Text {
                            anchors.centerIn: parent
                            color: confirmMouseArea.containsMouse ? (root.confirmationDisplayAction === "restart" ? "#15110a" : root.confirmationDisplayAction === "shutdown" ? "#fff0f3" : Colors.textOnAccent) : root.actionTone(root.confirmationDisplayAction)
                            font.family: Typography.textFamily
                            font.pixelSize: 12
                            font.weight: Font.ExtraBold
                            text: root.actionConfirmLabel(root.confirmationDisplayAction)
                        }

                        MouseArea {
                            id: confirmMouseArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.confirmationAction !== "" && !powerActionProcess.running
                            hoverEnabled: true

                            onClicked: root.confirmPowerAction()
                        }
                    }
                }
            }
        }
    }
}
