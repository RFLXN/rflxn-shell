import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "../../../theme"
import "../../state"

FocusScope {
    id: root

    property bool active: false
    property int activeIndex: -1
    property bool componentReady: false
    property int maxResults: 16
    property string query: ""
    property var results: []
    property var pendingLaunchApp: null
    property bool pointerHoverSuppressed: false
    property bool pointerPositionKnown: false
    property real pointerRootX: 0
    property real pointerRootY: 0
    property real pointerMoveThreshold: 0.5
    readonly property string appsFingerprint: applicationsFingerprint()

    width: parent?.width ?? 640
    height: parent?.height ?? 560

    function applicationsFingerprint() {
        const apps = visibleApplications();

        return apps.map(app => `${app.id}:${app.name}:${app.comment}:${app.noDisplay}`).join("\n");
    }

    function appLabel(app) {
        const name = String(app?.name ?? "").trim();
        const id = String(app?.id ?? "").trim();

        return name || id || "Unknown Application";
    }

    function appDescription(app) {
        return String(app?.comment || app?.genericName || "").trim();
    }

    function appSearchText(app) {
        return [
            app?.name,
            app?.genericName,
            app?.comment,
            app?.id,
            (app?.categories ?? []).join(" "),
            (app?.keywords ?? []).join(" ")
        ].join(" ").toLowerCase();
    }

    function clampActiveIndex(index, sourceResults) {
        const items = sourceResults ?? root.results;

        if (items.length === 0)
            return -1;

        return Math.max(0, Math.min(index, items.length - 1));
    }

    function fuzzyGap(text, token) {
        let searchIndex = 0;
        let firstMatch = -1;
        let lastMatch = -1;

        for (let tokenIndex = 0; tokenIndex < token.length; tokenIndex++) {
            const nextIndex = text.indexOf(token[tokenIndex], searchIndex);

            if (nextIndex < 0)
                return -1;

            if (firstMatch < 0)
                firstMatch = nextIndex;

            lastMatch = nextIndex;
            searchIndex = nextIndex + 1;
        }

        return Math.max(0, lastMatch - firstMatch - token.length + 1);
    }

    function matchScore(app, normalizedQuery) {
        if (!normalizedQuery)
            return 0;

        const name = appLabel(app).toLowerCase();
        const text = appSearchText(app);
        const tokens = normalizedQuery.split(/\s+/).filter(Boolean);
        let score = 0;

        for (const token of tokens) {
            if (name === token) {
                score += 0;
                continue;
            }

            if (name.startsWith(token)) {
                score += 8;
                continue;
            }

            const nameIndex = name.indexOf(token);

            if (nameIndex >= 0) {
                score += 32 + nameIndex;
                continue;
            }

            const textIndex = text.indexOf(token);

            if (textIndex >= 0) {
                score += 72 + textIndex;
                continue;
            }

            const gap = fuzzyGap(text, token);

            if (gap < 0)
                return -1;

            score += 128 + gap;
        }

        return score;
    }

    function moveActiveIndex(offset) {
        if (root.results.length === 0) {
            root.activeIndex = -1;
            return;
        }

        const baseIndex = root.activeIndex < 0 ? 0 : root.activeIndex;

        root.activeIndex = (baseIndex + offset + root.results.length) % root.results.length;
    }

    function shouldActivatePointerHover(item, x, y) {
        const point = item.mapToItem(root, x, y);
        const moved = !root.pointerPositionKnown || Math.abs(point.x - root.pointerRootX) > root.pointerMoveThreshold || Math.abs(point.y - root.pointerRootY) > root.pointerMoveThreshold;

        root.pointerRootX = point.x;
        root.pointerRootY = point.y;
        root.pointerPositionKnown = true;

        if (!root.pointerHoverSuppressed)
            return true;

        if (!moved)
            return false;

        root.pointerHoverSuppressed = false;
        return true;
    }

    function suppressPointerHover() {
        root.pointerHoverSuppressed = true;
    }

    function refreshResults(resetActive) {
        const normalizedQuery = root.query.trim().toLowerCase();
        const scored = [];

        for (const app of visibleApplications()) {
            const score = matchScore(app, normalizedQuery);

            if (score >= 0)
                scored.push({
                    app,
                    label: appLabel(app),
                    score
                });
        }

        scored.sort((left, right) => {
            const scoreDiff = left.score - right.score;

            if (scoreDiff !== 0)
                return scoreDiff;

            return left.label.localeCompare(right.label);
        });

        root.results = (normalizedQuery ? scored.slice(0, root.maxResults) : scored).map(item => item.app);
        root.activeIndex = resetActive ? clampActiveIndex(0, root.results) : clampActiveIndex(root.activeIndex, root.results);
    }

    function resetContent() {
        root.query = "";
        searchInput.text = "";
        root.pointerHoverSuppressed = false;
        root.pointerPositionKnown = false;
        refreshResults(true);
    }

    function resetForOpen() {
        resetContent();
        focusTimer.restart();
    }

    function selectedApplication() {
        if (root.activeIndex < 0 || root.activeIndex >= root.results.length)
            return null;

        return root.results[root.activeIndex];
    }

    function visibleApplications() {
        const values = DesktopEntries.applications.values ?? [];
        const apps = [];

        for (let index = 0; index < values.length; index++) {
            const app = values[index];

            if (app && app.noDisplay !== true)
                apps.push(app);
        }

        return apps;
    }

    function launchApplication(app) {
        if (!app)
            return false;

        if (detachedLaunchProcess.running)
            return false;

        root.pendingLaunchApp = app;
        detachedLaunchProcess.exec(detachedLaunchCommand(app));

        return true;
    }

    function detachedLaunchCommand(app) {
        const targets = uwsmLaunchTargets(app);
        const command = launchCommand(app);
        const script = [
            "target_count=\"$1\"",
            "shift",
            "index=0",
            "if command -v uwsm >/dev/null 2>&1; then",
            "  while [ \"$index\" -lt \"$target_count\" ]; do",
            "    target=\"$1\"",
            "    shift",
            "    index=$((index + 1))",
            "    uwsm app -t service -S both -- \"$target\" >/dev/null 2>&1 && exit 0",
            "  done",
            "else",
            "  while [ \"$index\" -lt \"$target_count\" ]; do",
            "    shift",
            "    index=$((index + 1))",
            "  done",
            "fi",
            "if [ \"$#\" -gt 0 ] && command -v systemd-run >/dev/null 2>&1; then",
            "  exec systemd-run --user --collect --quiet --slice=app-graphical.slice -- \"$@\"",
            "fi",
            "exit 127"
        ].join("\n");

        return ["sh", "-c", script, "app-launcher", String(targets.length)].concat(targets).concat(command);
    }

    function launchCommand(app) {
        const command = app?.command ?? [];
        const argv = [];

        for (let index = 0; index < command.length; index++) {
            const arg = String(command[index] ?? "").trim();

            if (arg)
                argv.push(arg);
        }

        return argv;
    }

    function launchWithDesktopEntry(app) {
        try {
            app.execute();
            completeLaunch();
            return true;
        } catch (error) {
            console.error(`Failed to launch ${appLabel(app)}`, error);
            clearPendingLaunch();
            return false;
        }
    }

    function launchSelectedApplication() {
        return launchApplication(selectedApplication());
    }

    function clearPendingLaunch() {
        root.pendingLaunchApp = null;
    }

    function completeLaunch() {
        clearPendingLaunch();
        resetContent();
        GlobalMenu.closeMenu("app-launcher");
    }

    function unique(values) {
        const seen = {};
        const next = [];

        for (const value of values) {
            const text = String(value ?? "").trim();

            if (!text || seen[text])
                continue;

            seen[text] = true;
            next.push(text);
        }

        return next;
    }

    function uwsmLaunchTargets(app) {
        const desktopEntry = String(app?.id ?? "").trim();

        if (!desktopEntry)
            return [];

        return unique([
            desktopEntry.endsWith(".desktop") || desktopEntry.includes(".desktop:") ? desktopEntry : `${desktopEntry}.desktop`
        ]);
    }

    onActiveChanged: {
        if (!componentReady)
            return;

        if (active) {
            resetForOpen();
        } else {
            focusTimer.stop();
        }
    }

    onAppsFingerprintChanged: refreshResults(false)
    onQueryChanged: refreshResults(true)

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            root.refreshResults(false);
        }
    }

    Process {
        id: detachedLaunchProcess

        onExited: exitCode => {
            if (exitCode === 0) {
                root.completeLaunch();
                return;
            }

            root.launchWithDesktopEntry(root.pendingLaunchApp);
        }
    }

    Timer {
        id: focusTimer

        interval: 0
        repeat: false

        onTriggered: {
            if (!root.active)
                return;

            root.forceActiveFocus();
            searchInput.forceActiveFocus();
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            id: searchBox

            width: parent.width
            height: 44
            border.color: Colors.widgetBorder
            border.width: 1
            color: Colors.widgetBgHover
            radius: height / 2

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 14
                    right: parent.right
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }

                color: Colors.textMuted
                elide: Text.ElideRight
                font.family: Typography.textFamily
                font.pixelSize: 15
                text: "Search applications"
                visible: searchInput.text.length === 0
            }

            TextInput {
                id: searchInput

                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 14
                }

                clip: true
                color: Colors.textPrimary
                focus: true
                font.family: Typography.textFamily
                font.pixelSize: 15
                selectByMouse: true
                selectionColor: Colors.accentSoft
                selectedTextColor: Colors.textOnAccent
                verticalAlignment: TextInput.AlignVCenter

                Keys.onPressed: event => {
                    const isShiftTab = event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && Boolean(event.modifiers & Qt.ShiftModifier));

                    if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !isShiftTab)) {
                        root.suppressPointerHover();
                        root.moveActiveIndex(1);
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Up || isShiftTab) {
                        root.suppressPointerHover();
                        root.moveActiveIndex(-1);
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.launchSelectedApplication();
                        event.accepted = true;
                    }

                    if (event.key === Qt.Key_Escape) {
                        GlobalMenu.closeActiveMenu();
                        event.accepted = true;
                    }
                }

                onTextChanged: {
                    if (root.query !== text)
                        root.query = text;
                }
            }
        }

        ListView {
            id: resultsView

            width: parent.width
            height: Math.max(0, parent.height - searchBox.height - parent.spacing)
            boundsBehavior: Flickable.StopAtBounds
            bottomMargin: 4
            cacheBuffer: 116
            clip: true
            model: root.results
            reuseItems: true
            spacing: 4
            topMargin: 4

            function ensureActiveVisible() {
                if (root.activeIndex >= 0)
                    positionViewAtIndex(root.activeIndex, ListView.Contain);
            }

            delegate: Rectangle {
                id: row

                required property int index
                required property var modelData

                readonly property bool selected: index === root.activeIndex
                readonly property string label: root.appLabel(modelData)
                readonly property string description: root.appDescription(modelData)
                readonly property string iconName: String(modelData?.icon ?? "")

                width: resultsView.width
                height: 58
                color: selected ? Colors.widgetBgHover : Colors.widgetBg
                radius: 18

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                        easing.type: Easing.OutQuad
                    }
                }

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }

                    spacing: 12

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        color: "transparent"
                        radius: 14

                        IconImage {
                            id: appIcon

                            anchors.centerIn: parent
                            width: 34
                            height: 34
                            asynchronous: true
                            implicitSize: 34
                            mipmap: true
                            source: row.iconName ? `image://icon/${row.iconName}` : ""
                            visible: source !== "" && status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            color: Colors.textPrimary
                            font.family: Typography.textFamily
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            text: row.label.charAt(0).toUpperCase()
                            visible: !appIcon.visible
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60
                        spacing: 2

                        Text {
                            width: parent.width
                            color: Colors.textPrimary
                            elide: Text.ElideRight
                            font.family: Typography.textFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: row.label
                        }

                        Text {
                            width: parent.width
                            color: Colors.textMuted
                            elide: Text.ElideRight
                            font.family: Typography.textFamily
                            font.pixelSize: 13
                            text: row.description
                            visible: row.description.length > 0
                        }
                    }
                }

                MouseArea {
                    id: pointerArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.launchApplication(row.modelData)
                    onEntered: {
                        if (root.shouldActivatePointerHover(pointerArea, pointerArea.mouseX, pointerArea.mouseY))
                            root.activeIndex = row.index;
                    }
                    onPositionChanged: mouse => {
                        if (root.shouldActivatePointerHover(pointerArea, mouse.x, mouse.y))
                            root.activeIndex = row.index;
                    }
                }
            }

            header: Item {
                width: resultsView.width
                height: root.results.length === 0 ? 180 : 0

                Text {
                    anchors.centerIn: parent
                    color: Colors.textMuted
                    font.family: Typography.textFamily
                    font.pixelSize: 14
                    text: "No applications found"
                }
            }

            onHeightChanged: ensureActiveVisible()

            Connections {
                target: root

                function onActiveIndexChanged() {
                    resultsView.ensureActiveVisible();
                }

                function onResultsChanged() {
                    resultsView.positionViewAtBeginning();
                    resultsView.ensureActiveVisible();
                }
            }
        }
    }

    Component.onCompleted: {
        componentReady = true;

        if (active) {
            resetForOpen();
        } else {
            refreshResults(true);
        }
    }
}
