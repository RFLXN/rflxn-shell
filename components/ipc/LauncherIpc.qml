import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../state"

IpcHandler {
    id: root

    target: "launcher"

    function close(): string {
        GlobalMenu.closeMenu("app-launcher");
        return "launcher closed";
    }

    function open(): string {
        const focusedName = String(Hyprland.focusedMonitor?.name ?? "");
        let screenName = GlobalMenu.isMenuAvailable("app-launcher", focusedName) ? focusedName : "";

        if (!screenName) {
            const screens = Quickshell.screens ?? [];

            for (let index = 0; index < screens.length; index++) {
                const screen = screens[index];
                const monitorName = String(Hyprland.monitorFor(screen)?.name ?? "");
                const candidateName = monitorName || String(screen?.name ?? "");

                if (GlobalMenu.isMenuAvailable("app-launcher", candidateName)) {
                    screenName = candidateName;
                    break;
                }
            }
        }

        if (!screenName || !GlobalMenu.openMenu("app-launcher", screenName))
            return "launcher unavailable";

        return "launcher opened";
    }

    function toggle(): string {
        if (GlobalMenu.activeMenu === "app-launcher") {
            GlobalMenu.closeMenu("app-launcher");
            return "launcher toggled";
        }

        const result = root.open();

        if (result !== "launcher opened")
            return result;

        return "launcher toggled";
    }
}
