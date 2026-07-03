import QtQuick
import "../../menu"

SideMenu {
    id: root

    contentPadding: 10
    cornerRadius: 24
    direction: "bottom"
    menuHeight: 560
    menuId: "app-launcher"
    menuMargin: 0
    menuWidth: 640

    AppLauncher {
        anchors.fill: parent
        active: root.menuOpen
    }
}
