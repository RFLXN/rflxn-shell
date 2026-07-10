pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "./config"
import "./components/bar"
import "./components/menu"
import "./components/widgets/applauncher"
import "./components/widgets/datetime"
import "./components/widgets/feedhub"
import "./components/widgets/systemcontrols"

Scope {
    id: root

    property var modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property string screenName: monitor?.name ?? ""
    readonly property var layout: Layouts.layoutForScreen(screenName)
    readonly property var appLauncherMenuConfig: Layouts.menuConfig(layout, "app-launcher")
    readonly property var calendarMenuConfig: Layouts.menuConfig(layout, "calendar")
    readonly property var feedHubMenuConfig: Layouts.menuConfig(layout, "feed-hub")
    readonly property var notificationPopupsConfig: Object.assign({}, Layouts.defaultNotificationPopups, Layouts.overlayConfig(layout, "notification-popups") ?? {})
    readonly property var systemControlsMenuConfig: Layouts.menuConfig(layout, "system-controls")

    Bar {
        modelData: root.modelData
        screenName: root.screenName
        leftWidgets: Layouts.slotWidgets(root.layout, "left")
        centerWidgets: Layouts.slotWidgets(root.layout, "center")
        rightWidgets: Layouts.slotWidgets(root.layout, "right")
    }

    Loader {
        active: Layouts.hasOverlay(root.layout, "app-launcher-menu")
        sourceComponent: appLauncherMenuComponent
    }

    Loader {
        active: Layouts.hasOverlay(root.layout, "calendar-menu")
        sourceComponent: calendarMenuComponent
    }

    Loader {
        active: Layouts.hasOverlay(root.layout, "feed-hub-menu")
        sourceComponent: feedHubMenuComponent
    }

    Loader {
        active: Layouts.hasOverlay(root.layout, "system-controls-menu")
        sourceComponent: systemControlsMenuComponent
    }

    Loader {
        active: Layouts.hasOverlay(root.layout, "global-menu-close-layer")
        sourceComponent: globalMenuCloseLayerComponent
    }

    Loader {
        active: Layouts.hasOverlay(root.layout, "notification-popups")
        sourceComponent: notificationPopupsComponent
    }

    Component {
        id: appLauncherMenuComponent

        AppLauncherMenu {
            modelData: root.modelData
            screenName: root.screenName
            direction: root.appLauncherMenuConfig.direction ?? "bottom"
            menuWidth: root.appLauncherMenuConfig.menuWidth ?? 640
            menuHeight: root.appLauncherMenuConfig.menuHeight ?? 560
            menuMargin: root.appLauncherMenuConfig.menuMargin ?? 0
            contentPadding: root.appLauncherMenuConfig.contentPadding ?? 10
            cornerRadius: root.appLauncherMenuConfig.cornerRadius ?? 24
            alignment: root.appLauncherMenuConfig.alignment ?? "center"
        }
    }

    Component {
        id: calendarMenuComponent

        CalendarMenu {
            modelData: root.modelData
            screenName: root.screenName
            direction: root.calendarMenuConfig.direction ?? "top"
            menuWidth: root.calendarMenuConfig.menuWidth ?? 360
            menuHeight: root.calendarMenuConfig.menuHeight ?? 380
            menuMargin: root.calendarMenuConfig.menuMargin ?? 0
            contentPadding: root.calendarMenuConfig.contentPadding ?? 18
            cornerRadius: root.calendarMenuConfig.cornerRadius ?? 24
            alignment: root.calendarMenuConfig.alignment ?? "center"
        }
    }

    Component {
        id: feedHubMenuComponent

        FeedHubMenu {
            modelData: root.modelData
            screenName: root.screenName
            direction: root.feedHubMenuConfig.direction ?? "left"
            menuWidth: root.feedHubMenuConfig.menuWidth ?? 450
            menuMargin: root.feedHubMenuConfig.menuMargin ?? 6
            menuTopOffset: root.feedHubMenuConfig.menuTopOffset ?? 0
            contentPadding: root.feedHubMenuConfig.contentPadding ?? 5
            cornerRadius: root.feedHubMenuConfig.cornerRadius ?? 23
        }
    }

    Component {
        id: systemControlsMenuComponent

        SystemControlsMenu {
            modelData: root.modelData
            screenName: root.screenName
            direction: root.systemControlsMenuConfig.direction ?? "right"
            menuWidth: root.systemControlsMenuConfig.menuWidth ?? 420
            menuMargin: root.systemControlsMenuConfig.menuMargin ?? 6
            menuTopOffset: root.systemControlsMenuConfig.menuTopOffset ?? 0
            contentPadding: root.systemControlsMenuConfig.contentPadding ?? 18
            cornerRadius: root.systemControlsMenuConfig.cornerRadius ?? 23
            programs: root.systemControlsMenuConfig.programs ?? ({})
        }
    }

    Component {
        id: globalMenuCloseLayerComponent

        GlobalMenuCloseLayer {
            modelData: root.modelData
            screenName: root.screenName
        }
    }

    Component {
        id: notificationPopupsComponent

        FeedHubNotificationPopups {
            modelData: root.modelData
            screenName: root.screenName
            margin: root.notificationPopupsConfig.margin ?? 8
            maxVisible: root.notificationPopupsConfig.maxVisible ?? 3
            popupWidth: root.notificationPopupsConfig.popupWidth ?? 392
            position: root.notificationPopupsConfig.position ?? "top-right"
            timeoutMs: root.notificationPopupsConfig.timeoutMs ?? 6000
        }
    }
}
