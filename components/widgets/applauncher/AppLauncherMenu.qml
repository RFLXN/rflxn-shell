pragma ComponentBehavior: Bound

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

    Loader {
        anchors.fill: parent
        active: root.mounted
        sourceComponent: Component {
            AppLauncher {
                active: root.menuOpen
            }
        }
    }
}
