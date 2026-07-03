pragma Singleton

import QtQuick

QtObject {
    readonly property int barHeight: 46
    readonly property int globalYSpacing: 6
    readonly property int widgetHeight: barHeight - globalYSpacing * 2
    readonly property int compactIndicatorSize: widgetHeight - globalYSpacing * 2
    readonly property int compactIconSize: compactIndicatorSize - globalYSpacing
    readonly property int workspaceWindowIconSpacing: 8
    readonly property int workspaceWindowIconSize: widgetHeight - workspaceWindowIconSpacing * 2
}
