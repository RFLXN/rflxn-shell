pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property var defaultBar: ({
            left: ["window-title"],
            center: ["workspaces", "datetime"],
            right: ["system-controls"]
        })
    readonly property var defaultSystemControlsMenu: ({
            direction: "right",
            menuWidth: 420,
            menuMargin: 6,
            contentPadding: 18,
            cornerRadius: 23,
            programs: {
                volume: {
                    command: "pwvucontrol",
                    rules: "float; size 900 650; center"
                },
                bluetooth: {
                    command: "blueman-manager",
                    rules: "float; size 760 560; center"
                },
                network: {
                    command: "nm-connection-editor",
                    rules: "float; size 880 640; center"
                }
            }
        })
    readonly property var defaultAppLauncherMenu: ({
            direction: "bottom",
            menuWidth: 640,
            menuHeight: 560,
            menuMargin: 0,
            contentPadding: 10,
            cornerRadius: 24,
            alignment: "center"
        })
    readonly property var defaultCalendarMenu: ({
            direction: "top",
            menuWidth: 360,
            menuHeight: 380,
            menuMargin: 0,
            contentPadding: 18,
            cornerRadius: 24,
            alignment: "center"
        })
    readonly property var defaultFeedHubMenu: ({
            direction: "left",
            menuWidth: 450,
            menuMargin: 6,
            menuTopOffset: 0,
            contentPadding: 5,
            cornerRadius: 23
        })
    readonly property var defaultNotificationPopups: ({
            position: "top-right",
            timeoutMs: 6000,
            maxVisible: 3,
            margin: 8,
            popupWidth: 392
        })
    readonly property var fallbackLayout: ({
            bar: defaultBar,
            menus: {
                "app-launcher": defaultAppLauncherMenu,
                "calendar": defaultCalendarMenu,
                "feed-hub": defaultFeedHubMenu,
                "system-controls": defaultSystemControlsMenu
            },
            overlays: [
                {
                    id: "system-controls-menu"
                },
                {
                    id: "global-menu-close-layer"
                }
            ]
        })

    readonly property string configPath: `${Quickshell.shellDir}/layout.json`
    readonly property var config: parseConfig(layoutFile.text())
    readonly property var layouts: config.layouts

    property FileView layoutFile: FileView {
        id: layoutFile

        path: root.configPath
        preload: true
        printErrors: true
        watchChanges: true

        onLoadFailed: error => console.error(`Failed to load layout config: ${FileViewError.toString(error)}`)
    }

    function barLayout(layout) {
        return layout?.bar ?? root.defaultBar;
    }

    function layoutForScreen(screenName) {
        const name = String(screenName ?? "");

        return root.layouts[name] ?? root.fallbackLayout;
    }

    function menuConfig(layout, menuId) {
        const menus = layout?.menus ?? {};
        const fallbackMenus = root.fallbackLayout.menus ?? {};
        const fallbackConfig = fallbackMenus[menuId] ?? {};
        const config = menus[menuId] ?? {};

        return Object.assign({}, fallbackConfig, config);
    }

    function overlayConfig(layout, overlayId) {
        const overlays = layout?.overlays ?? [];

        for (const overlay of overlays) {
            const id = typeof overlay === "string" ? overlay : String(overlay?.id ?? "");

            if (id === overlayId && overlay?.enabled !== false)
                return typeof overlay === "string" ? {
                    id
                } : overlay;
        }

        return null;
    }

    function hasOverlay(layout, overlayId) {
        return overlayConfig(layout, overlayId) !== null;
    }

    function menuOverlayId(menuId) {
        const id = String(menuId ?? "");

        if (id === "app-launcher")
            return "app-launcher-menu";

        if (id === "calendar")
            return "calendar-menu";

        if (id === "feed-hub")
            return "feed-hub-menu";

        if (id === "system-controls")
            return "system-controls-menu";

        return "";
    }

    function hasMenuOverlay(screenName, menuId) {
        const name = String(screenName ?? "");
        const overlayId = menuOverlayId(menuId);

        return name !== "" && overlayId !== "" && hasOverlay(layoutForScreen(name), overlayId);
    }

    function slotWidgets(layout, slot) {
        const bar = barLayout(layout);
        const widgets = bar?.[slot] ?? [];

        return Array.isArray(widgets) ? widgets : [];
    }

    function isRecord(value) {
        return typeof value === "object" && value !== null && !Array.isArray(value);
    }

    function isStringArray(value) {
        return Array.isArray(value) && value.every(item => typeof item === "string");
    }

    function knownWidgetId(value) {
        return value === "datetime" || value === "feed-hub" || value === "system-controls" || value === "window-title" || value === "workspaces";
    }

    function knownMenuId(value) {
        return value === "app-launcher" || value === "calendar" || value === "feed-hub" || value === "system-controls";
    }

    function knownOverlayId(value) {
        return value === "app-launcher-menu" || value === "calendar-menu" || value === "feed-hub-menu" || value === "global-menu-close-layer" || value === "notification-popups" || value === "system-controls-menu";
    }

    function normalizeEnumField(value, field, allowed, context) {
        if (!Object.prototype.hasOwnProperty.call(value, field))
            return;

        if (!allowed.includes(value[field])) {
            console.warn(`Invalid ${context}.${field}: ${value[field]}`);
            delete value[field];
        }
    }

    function normalizeNumberField(value, field, minimum, maximum, context) {
        if (!Object.prototype.hasOwnProperty.call(value, field))
            return;

        const number = value[field];

        if (typeof number !== "number" || !Number.isFinite(number) || number < minimum || number > maximum) {
            console.warn(`Invalid ${context}.${field}: ${number}`);
            delete value[field];
        }
    }

    function normalizeBooleanField(value, field, context) {
        if (!Object.prototype.hasOwnProperty.call(value, field))
            return;

        if (typeof value[field] !== "boolean") {
            console.warn(`Invalid ${context}.${field}: ${value[field]}`);
            delete value[field];
        }
    }

    function normalizeMenuConfig(value, menuId) {
        if (!isRecord(value)) {
            console.warn(`Invalid layout menu config: ${menuId}`);
            return {};
        }

        const normalized = Object.assign({}, value);
        const context = `menu ${menuId}`;

        normalizeEnumField(normalized, "direction", ["left", "right", "top", "bottom"], context);
        normalizeEnumField(normalized, "alignment", ["left", "center", "right"], context);
        normalizeNumberField(normalized, "menuWidth", 1, 16384, context);
        normalizeNumberField(normalized, "menuHeight", 1, 16384, context);
        normalizeNumberField(normalized, "menuMargin", 0, 4096, context);
        normalizeNumberField(normalized, "menuTopOffset", -16384, 16384, context);
        normalizeNumberField(normalized, "contentPadding", 0, 4096, context);
        normalizeNumberField(normalized, "cornerRadius", 0, 4096, context);

        if (Object.prototype.hasOwnProperty.call(normalized, "programs") && !isRecord(normalized.programs)) {
            console.warn(`Invalid ${context}.programs`);
            delete normalized.programs;
        }

        return normalized;
    }

    function normalizeMenuMap(value) {
        if (!isRecord(value))
            return {};

        const menus = {};

        for (const id of Object.keys(value)) {
            if (!knownMenuId(id)) {
                console.warn(`Unknown layout menu: ${id}`);
                continue;
            }

            menus[id] = normalizeMenuConfig(value[id], id);
        }

        return menus;
    }

    function normalizeOverlay(value) {
        const id = typeof value === "string" ? value : String(value?.id ?? "");

        if (!knownOverlayId(id)) {
            console.warn(`Unknown layout overlay: ${id}`);
            return null;
        }

        if (typeof value === "string")
            return {
                id
            };

        const normalized = Object.assign({}, value, {
                id
            });
        const context = `overlay ${id}`;

        normalizeBooleanField(normalized, "enabled", context);

        if (id === "notification-popups") {
            normalizeEnumField(normalized, "position", ["top-left", "top-right", "bottom-left", "bottom-right"], context);
            normalizeNumberField(normalized, "timeoutMs", 1, 86400000, context);
            normalizeNumberField(normalized, "maxVisible", 1, 100, context);
            normalizeNumberField(normalized, "margin", 0, 4096, context);
            normalizeNumberField(normalized, "popupWidth", 1, 16384, context);
        }

        return normalized;
    }

    function normalizeOverlays(layout) {
        const rawOverlays = Array.isArray(layout?.overlays) ? layout.overlays : layout?.components;
        const overlays = Array.isArray(rawOverlays) ? rawOverlays : [];
        const normalized = [];

        for (const overlay of overlays) {
            const next = normalizeOverlay(overlay);

            if (next !== null)
                normalized.push(next);
        }

        return normalized;
    }

    function normalizeWidgetSlots(value) {
        const source = isRecord(value) ? value : {};

        return {
            left: normalizeWidgets(source.left),
            center: normalizeWidgets(source.center),
            right: normalizeWidgets(source.right)
        };
    }

    function normalizeWidgets(value) {
        if (!isStringArray(value))
            return [];

        const widgets = [];

        for (const widgetId of value) {
            if (knownWidgetId(widgetId)) {
                widgets.push(widgetId);
            } else {
                console.warn(`Unknown layout widget: ${widgetId}`);
            }
        }

        return widgets;
    }

    function normalizeLayout(value) {
        if (!isRecord(value) || typeof value.monitor !== "string" || value.monitor.trim() === "") {
            console.warn("Invalid layout definition", value);
            return null;
        }

        return {
            bar: normalizeWidgetSlots(value.bar ?? value.widgets),
            menus: normalizeMenuMap(value.menus),
            monitor: value.monitor.trim(),
            overlays: normalizeOverlays(value)
        };
    }

    function normalizeLayoutList(value) {
        if (!Array.isArray(value))
            return {};

        const next = {};

        for (const item of value) {
            const layout = normalizeLayout(item);

            if (layout !== null) {
                if (Object.prototype.hasOwnProperty.call(next, layout.monitor))
                    console.warn(`Duplicate layout monitor: ${layout.monitor}`);

                next[layout.monitor] = layout;
            }
        }

        return next;
    }

    function parseConfig(text) {
        if (!String(text ?? "").trim())
            return {
                layouts: {}
            };

        try {
            const parsed = JSON.parse(text);

            if (!isRecord(parsed) || !Array.isArray(parsed.layouts)) {
                console.warn("Invalid layout config", parsed);
                return {
                    layouts: {}
                };
            }

            return {
                layouts: normalizeLayoutList(parsed.layouts)
            };
        } catch (error) {
            console.error("Failed to parse layout config", error);
            return {
                layouts: {}
            };
        }
    }
}
