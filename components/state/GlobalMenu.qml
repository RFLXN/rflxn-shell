pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property int transitionDuration: 500
    readonly property bool anyMenuOpen: activeMenu !== ""
    property string activeMenu: ""
    property string activeScreenName: ""

    function closeActiveMenu() {
        if (root.activeMenu === "")
            return;

        root.activeMenu = "";
        root.activeScreenName = "";
    }

    function closeMenu(menuId) {
        if (root.activeMenu !== menuId)
            return;

        root.closeActiveMenu();
    }

    function isActiveScreen(screenName) {
        const activeScreen = String(root.activeScreenName ?? "");
        const targetScreen = String(screenName ?? "");

        return activeScreen !== "" && activeScreen === targetScreen;
    }

    function isMenuOpen(menuId, screenName) {
        return root.activeMenu === menuId && root.isActiveScreen(screenName);
    }

    function openMenu(menuId, screenName) {
        if (!menuId)
            return;

        const targetScreenName = String(screenName ?? "");

        if (!targetScreenName)
            return;

        root.activeMenu = String(menuId);
        root.activeScreenName = targetScreenName;
    }

    function toggleMenu(menuId, screenName) {
        const targetScreenName = String(screenName ?? "");

        if (root.activeMenu === menuId && root.isActiveScreen(targetScreenName)) {
            root.closeActiveMenu();
            return;
        }

        root.openMenu(menuId, targetScreenName);
    }
}
