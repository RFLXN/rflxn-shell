pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../config"

QtObject {
    id: root

    readonly property int transitionDuration: 500
    readonly property bool anyMenuOpen: activeMenu !== "" && isMenuAvailable(activeMenu, activeScreenName)
    property string activeMenu: ""
    property string activeScreenName: ""

    property Connections layoutConnections: Connections {
        target: Layouts

        function onLayoutsChanged() {
            root.reconcileActiveMenu();
        }
    }

    property Connections screenConnections: Connections {
        target: Quickshell

        function onScreensChanged() {
            root.reconcileActiveMenu();
        }
    }

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

    function isScreenAvailable(screenName) {
        const targetName = String(screenName ?? "");
        const screens = Quickshell.screens ?? [];

        if (!targetName)
            return false;

        for (let index = 0; index < screens.length; index++) {
            const screen = screens[index];
            const nativeName = String(screen?.name ?? "");
            const monitorName = String(Hyprland.monitorFor(screen)?.name ?? "");

            if (targetName === monitorName || targetName === nativeName)
                return true;
        }

        return false;
    }

    function isMenuAvailable(menuId, screenName) {
        const targetMenu = String(menuId ?? "");
        const targetScreen = String(screenName ?? "");

        return targetMenu !== "" && root.isScreenAvailable(targetScreen) && Layouts.hasMenuOverlay(targetScreen, targetMenu);
    }

    function isMenuOpen(menuId, screenName) {
        return root.activeMenu === menuId && root.isActiveScreen(screenName) && root.isMenuAvailable(menuId, screenName);
    }

    function openMenu(menuId, screenName) {
        const targetMenu = String(menuId ?? "");
        const targetScreenName = String(screenName ?? "");

        if (!root.isMenuAvailable(targetMenu, targetScreenName))
            return false;

        root.activeMenu = targetMenu;
        root.activeScreenName = targetScreenName;
        return true;
    }

    function toggleMenu(menuId, screenName) {
        const targetMenu = String(menuId ?? "");
        const targetScreenName = String(screenName ?? "");

        if (root.activeMenu === targetMenu && root.isActiveScreen(targetScreenName)) {
            root.closeActiveMenu();
            return false;
        }

        return root.openMenu(targetMenu, targetScreenName);
    }

    function reconcileActiveMenu() {
        if (root.activeMenu !== "" && !root.isMenuAvailable(root.activeMenu, root.activeScreenName))
            root.closeActiveMenu();
    }
}
