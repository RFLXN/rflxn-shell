import Quickshell
import QtQuick
import "../../theme"
import "../widgets/datetime"
import "../widgets/feedhub"
import "../widgets/systemcontrols"
import "../widgets/windowtitle"
import "../widgets/workspaces"

PanelWindow {
    id: root

    property var modelData
    property var leftWidgets: ["window-title"]
    property var centerWidgets: ["workspaces", "datetime"]
    property var rightWidgets: ["system-controls"]
    property int railHeight: Metrics.barHeight
    property int skirtSize: Math.round(railHeight / 2)
    property int contentPadding: 24
    property int widgetSpacing: 12
    property string screenName: ""

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: railHeight + skirtSize
    exclusiveZone: railHeight
    focusable: false
    color: "transparent"
    surfaceFormat.opaque: false
    mask: Region {
        item: rail
    }

    function widgetComponent(widgetId) {
        if (widgetId === "datetime")
            return datetimeComponent;

        if (widgetId === "feed-hub")
            return feedHubComponent;

        if (widgetId === "system-controls")
            return systemControlsComponent;

        if (widgetId === "window-title")
            return windowTitleComponent;

        if (widgetId === "workspaces")
            return workspacesComponent;

        console.warn(`Unknown bar widget: ${widgetId}`);
        return null;
    }

    Component {
        id: datetimeComponent

        DateTime {
            screen: root.screen
            screenName: root.screenName
        }
    }

    Component {
        id: feedHubComponent

        FeedHub {
            screen: root.screen
            screenName: root.screenName
        }
    }

    Component {
        id: systemControlsComponent

        SystemControls {
            screen: root.screen
            screenName: root.screenName
        }
    }

    Component {
        id: windowTitleComponent

        WindowTitle {}
    }

    Component {
        id: workspacesComponent

        Workspaces {
            screen: root.screen
        }
    }

    Item {
        id: chrome

        anchors.fill: parent

        Rectangle {
            id: rail

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            height: root.railHeight
            color: Colors.barBg
        }

        Item {
            id: content

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: root.contentPadding
                rightMargin: root.contentPadding
            }

            height: root.railHeight
            clip: true

            Row {
                id: startSlot

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                spacing: root.widgetSpacing

                Repeater {
                    model: root.leftWidgets

                    Loader {
                        required property string modelData

                        sourceComponent: root.widgetComponent(modelData)
                    }
                }
            }

            Row {
                id: centerSlot

                anchors.centerIn: parent
                spacing: root.widgetSpacing

                Repeater {
                    model: root.centerWidgets

                    Loader {
                        required property string modelData

                        sourceComponent: root.widgetComponent(modelData)
                    }
                }
            }

            Row {
                id: endSlot

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                spacing: root.widgetSpacing

                Repeater {
                    model: root.rightWidgets

                    Loader {
                        required property string modelData

                        sourceComponent: root.widgetComponent(modelData)
                    }
                }
            }
        }

        Item {
            id: skirtRow

            anchors {
                top: rail.bottom
                left: parent.left
                right: parent.right
            }

            height: root.skirtSize

            BarSkirt {
                id: leftSkirt

                anchors {
                    top: parent.top
                    left: parent.left
                }

                width: root.skirtSize
                height: root.skirtSize
            }

            BarSkirt {
                id: rightSkirt

                anchors {
                    top: parent.top
                    right: parent.right
                }

                width: root.skirtSize
                height: root.skirtSize
                mirrored: true
            }
        }
    }
}
