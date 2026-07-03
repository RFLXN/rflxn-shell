import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../../config"
import "../state"

IpcHandler {
    id: root

    target: "launcher"

    function close(): string {
        GlobalMenu.closeMenu("app-launcher");
        return "launcher closed";
    }

    function open(): string {
        const screens = Quickshell.screens ?? [];

        for (let index = 0; index < screens.length; index++) {
            const monitor = Hyprland.monitorFor(screens[index]);
            const screenName = String(monitor?.name ?? "");

            if (screenName && Layouts.hasOverlay(Layouts.layoutForScreen(screenName), "app-launcher-menu")) {
                GlobalMenu.openMenu("app-launcher", screenName);
                return "launcher opened";
            }
        }

        for (let index = 0; index < screens.length; index++) {
            const monitor = Hyprland.monitorFor(screens[index]);
            const screenName = String(monitor?.name ?? "");

            if (screenName) {
                GlobalMenu.openMenu("app-launcher", screenName);
                return "launcher opened";
            }
        }

        GlobalMenu.openMenu("app-launcher", "");
        return "launcher opened";
    }

    function toggle(): string {
        const screens = Quickshell.screens ?? [];

        for (let index = 0; index < screens.length; index++) {
            const monitor = Hyprland.monitorFor(screens[index]);
            const screenName = String(monitor?.name ?? "");

            if (screenName && Layouts.hasOverlay(Layouts.layoutForScreen(screenName), "app-launcher-menu")) {
                GlobalMenu.toggleMenu("app-launcher", screenName);
                return "launcher toggled";
            }
        }

        for (let index = 0; index < screens.length; index++) {
            const monitor = Hyprland.monitorFor(screens[index]);
            const screenName = String(monitor?.name ?? "");

            if (screenName) {
                GlobalMenu.toggleMenu("app-launcher", screenName);
                return "launcher toggled";
            }
        }

        GlobalMenu.toggleMenu("app-launcher", "");
        return "launcher toggled";
    }
}
