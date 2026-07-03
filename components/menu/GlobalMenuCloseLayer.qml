import Quickshell
import QtQuick
import "../state"

PanelWindow {
    id: root

    property var modelData
    property string screenName: ""

    screen: modelData

    anchors {
        bottom: true
        left: true
        right: true
        top: true
    }

    color: "transparent"
    exclusiveZone: 0
    focusable: false
    surfaceFormat.opaque: false
    visible: GlobalMenu.anyMenuOpen && GlobalMenu.activeScreenName !== "" && !GlobalMenu.isActiveScreen(screenName)

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.01

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalMenu.closeActiveMenu()
        }
    }
}
