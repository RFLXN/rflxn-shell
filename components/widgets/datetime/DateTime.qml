import Quickshell.Hyprland
import QtQuick
import "../../../theme"
import "../../state"

Rectangle {
    id: root

    property string format: "yyyy-MM-dd hh:mm:ss AP"
    property date currentDate: new Date()
    readonly property string displayText: Qt.formatDateTime(currentDate, format)
    readonly property var displayTokens: buildDisplayTokens(displayText)
    property int horizontalPadding: 18
    property int separatorOpticalPadding: 2
    property string menuId: "calendar"
    property var screen
    property string textFontFamily: "Pretendard"
    property int textFontPixelSize: 16
    property int textFontWeight: Font.DemiBold
    readonly property bool active: GlobalMenu.isMenuOpen(menuId, screenName)
    readonly property int digitCellWidth: Math.ceil(Math.max(digit0Metric.advanceWidth, digit1Metric.advanceWidth, digit2Metric.advanceWidth, digit3Metric.advanceWidth, digit4Metric.advanceWidth, digit5Metric.advanceWidth, digit6Metric.advanceWidth, digit7Metric.advanceWidth, digit8Metric.advanceWidth, digit9Metric.advanceWidth))
    readonly property bool hovered: clickArea.containsMouse
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property string detectedScreenName: monitor?.name ?? ""
    readonly property int periodCellWidth: Math.ceil(Math.max(amMetric.advanceWidth, pmMetric.advanceWidth))
    property string screenName: detectedScreenName

    width: implicitWidth
    height: implicitHeight
    implicitWidth: datetimeRow.implicitWidth + horizontalPadding * 2
    implicitHeight: Metrics.widgetHeight
    radius: height / 2
    color: hovered || active ? Colors.widgetBgActive : "transparent"
    border.width: 1
    border.color: hovered || active ? Colors.widgetBorder : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    function buildDisplayTokens(text) {
        const tokens = [];

        for (let index = 0; index < text.length; index++) {
            const remainingText = text.slice(index);

            if (remainingText === "AM" || remainingText === "PM") {
                tokens.push({
                    kind: "period",
                    text: remainingText
                });
                break;
            }

            const character = text.charAt(index);
            tokens.push({
                kind: isDigit(character) ? "digit" : "separator",
                text: character
            });
        }

        return tokens;
    }

    function isDigit(character) {
        return character >= "0" && character <= "9";
    }

    function separatorCellWidth(character) {
        if (character === "-")
            return Math.ceil(dashMetric.advanceWidth) + separatorOpticalPadding * 2;

        if (character === ":")
            return Math.ceil(colonMetric.advanceWidth) + separatorOpticalPadding * 2;

        if (character === " ")
            return Math.ceil(spaceMetric.advanceWidth);

        return Math.ceil(fallbackSeparatorMetric.advanceWidth);
    }

    function tokenCellWidth(token) {
        if (token.kind === "digit")
            return digitCellWidth;

        if (token.kind === "period")
            return periodCellWidth;

        return separatorCellWidth(token.text);
    }

    function separatorTextOffset(character) {
        if (character === "-")
            return 1;

        if (character === ":")
            return 0;

        return 0;
    }

    function tokenTextOffset(token) {
        if (token.kind !== "separator")
            return 0;

        return separatorTextOffset(token.text);
    }

    function tokenAt(index) {
        return root.displayTokens[index] ?? {
            kind: "separator",
            text: ""
        };
    }

    Row {
        id: datetimeRow
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.displayTokens.length

            Item {
                id: tokenCell

                property var tokenData: root.tokenAt(index)

                width: root.tokenCellWidth(tokenData)
                height: root.height

                RollingDigit {
                    anchors.fill: parent
                    duration: 420
                    fontFamily: root.textFontFamily
                    fontPixelSize: root.textFontPixelSize
                    fontWeight: root.textFontWeight
                    textColor: Colors.textPrimary
                    value: tokenCell.tokenData.kind === "digit" ? tokenCell.tokenData.text : ""
                    visible: tokenCell.tokenData.kind === "digit"
                }

                Text {
                    visible: tokenCell.tokenData.kind !== "digit"

                    anchors {
                        centerIn: parent
                        horizontalCenterOffset: root.tokenTextOffset(tokenCell.tokenData)
                    }

                    color: Colors.textPrimary
                    font.family: root.textFontFamily
                    font.pixelSize: root.textFontPixelSize
                    font.weight: root.textFontWeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: tokenCell.tokenData.text
                }
            }
        }
    }

    TextMetrics {
        id: digit0Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "0"
    }

    TextMetrics {
        id: digit1Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "1"
    }

    TextMetrics {
        id: digit2Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "2"
    }

    TextMetrics {
        id: digit3Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "3"
    }

    TextMetrics {
        id: digit4Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "4"
    }

    TextMetrics {
        id: digit5Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "5"
    }

    TextMetrics {
        id: digit6Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "6"
    }

    TextMetrics {
        id: digit7Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "7"
    }

    TextMetrics {
        id: digit8Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "8"
    }

    TextMetrics {
        id: digit9Metric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "9"
    }

    TextMetrics {
        id: dashMetric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "-"
    }

    TextMetrics {
        id: colonMetric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: ":"
    }

    TextMetrics {
        id: spaceMetric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: " "
    }

    TextMetrics {
        id: fallbackSeparatorMetric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "-"
    }

    TextMetrics {
        id: amMetric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "AM"
    }

    TextMetrics {
        id: pmMetric

        font.family: root.textFontFamily
        font.pixelSize: root.textFontPixelSize
        font.weight: root.textFontWeight
        text: "PM"
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: root.currentDate = new Date()
    }

    MouseArea {
        id: clickArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: GlobalMenu.toggleMenu(root.menuId, root.screenName)
    }
}
