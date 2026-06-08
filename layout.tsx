import app from "ags/gtk4/app"
import type Gdk from "gi://Gdk?version=4.0"
import Bar from "./components/bar"
import AppLauncherMenu from "./components/widgets/app-launcher/menu"
import GlobalMenuCloseLayer from "./components/global-menu-close-layer"
import ShutdownConfirmationOverlay, {
  type ShutdownConfirmationAction,
} from "./components/shutdown-confirmation-overlay"
import { executeShutdownConfirmationAction } from "./components/shutdown-confirmation-overlay/actions"
import DateTimeWidget from "./components/widgets/datetime"
import FeedHubMenu from "./components/widgets/feed-hub/menu"
import FeedHubWidget from "./components/widgets/feed-hub"
import NotificationPopups from "./components/widgets/feed-hub/notification-popup"
import HwMonitorWidget from "./components/widgets/hw-monitor"
import WindowTitleWidget from "./components/widgets/hyprland/window-title"
import WorkspacesWidget from "./components/widgets/hyprland/workspaces"
import SystemControlsMenu from "./components/widgets/system-controls/menu"
import SystemControlsWidget from "./components/widgets/system-controls"
import VolumeOsd from "./components/widgets/system-controls/volume/osd"
import {
  activeShutdownConfirmationAction,
  closeShutdownConfirmation,
  isShutdownConfirmationVisible,
} from "./components/global-store"
import { toGdkMonitor } from "./utils/monitor"
import layoutConfigJson from "inline:./layout.json"

type LayoutWidgetId =
  | "datetime"
  | "feed-hub"
  | "hw-monitor"
  | "system-controls"
  | "window-title"
  | "workspaces"

type LayoutComponentId =
  | "app-launcher-menu"
  | "feed-hub-menu"
  | "global-menu-close-layer"
  | "shutdown-confirmation-overlay"
  | "system-controls-menu"
  | "system-controls-volume-osd"

type LayoutWidgetSlots = {
  left?: LayoutWidgetId[]
  center?: LayoutWidgetId[]
  right?: LayoutWidgetId[]
}

type LayoutDefinition = {
  monitor: string
  widgets?: LayoutWidgetSlots
  components?: LayoutComponentId[]
}

type LayoutConfig = {
  layouts: LayoutDefinition[]
}

const layoutConfig = parseLayoutConfig(layoutConfigJson)

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string")
}

function parseWidgetSlots(value: unknown): LayoutWidgetSlots {
  if (!isRecord(value)) return {}

  return {
    left: isStringArray(value.left) ? toKnownWidgetIds(value.left) : [],
    center: isStringArray(value.center) ? toKnownWidgetIds(value.center) : [],
    right: isStringArray(value.right) ? toKnownWidgetIds(value.right) : [],
  }
}

function toKnownWidgetIds(values: string[]): LayoutWidgetId[] {
  return values.filter((value): value is LayoutWidgetId => {
    if (isLayoutWidgetId(value)) return true

    console.error(`Unknown layout widget: ${value}`)
    return false
  })
}

function toKnownComponentIds(values: string[]): LayoutComponentId[] {
  return values.filter((value): value is LayoutComponentId => {
    if (isLayoutComponentId(value)) return true

    console.error(`Unknown layout component: ${value}`)
    return false
  })
}

function isLayoutWidgetId(value: string): value is LayoutWidgetId {
  return [
    "datetime",
    "feed-hub",
    "hw-monitor",
    "system-controls",
    "window-title",
    "workspaces",
  ].includes(value)
}

function isLayoutComponentId(value: string): value is LayoutComponentId {
  return [
    "app-launcher-menu",
    "feed-hub-menu",
    "global-menu-close-layer",
    "shutdown-confirmation-overlay",
    "system-controls-menu",
    "system-controls-volume-osd",
  ].includes(value)
}

function parseLayoutDefinition(value: unknown): LayoutDefinition | null {
  if (!isRecord(value) || typeof value.monitor !== "string") {
    console.error("Invalid layout definition", value)
    return null
  }

  return {
    monitor: value.monitor,
    widgets: parseWidgetSlots(value.widgets),
    components: isStringArray(value.components)
      ? toKnownComponentIds(value.components)
      : [],
  }
}

function parseLayoutConfig(json: string): LayoutConfig {
  try {
    const parsed = JSON.parse(json) as unknown

    if (!isRecord(parsed) || !Array.isArray(parsed.layouts)) {
      console.error("Invalid layout config", parsed)
      return { layouts: [] }
    }

    return {
      layouts: parsed.layouts
        .map(parseLayoutDefinition)
        .filter((layout): layout is LayoutDefinition => layout !== null),
    }
  } catch (error) {
    console.error("Failed to parse layout config", error)
    return { layouts: [] }
  }
}

function renderWidget(id: LayoutWidgetId, monitorName: string) {
  switch (id) {
    case "datetime":
      return <DateTimeWidget />
    case "feed-hub":
      return <FeedHubWidget />
    case "hw-monitor":
      return (
        <HwMonitorWidget pollingRate={{ cpu: 1000, gpu: 1000, ram: 1000 }} />
      )
    case "system-controls":
      return <SystemControlsWidget />
    case "window-title":
      return <WindowTitleWidget />
    case "workspaces":
      return <WorkspacesWidget monitorName={monitorName} />
  }
}

function renderWidgets(
  ids: LayoutWidgetId[] | undefined,
  monitorName: string,
) {
  return ids?.map((id) => renderWidget(id, monitorName)) ?? []
}

function renderCloseLayers(gdkmonitor: Gdk.Monitor) {
  return app
    .get_monitors()
    .filter((monitor) => monitor.get_connector() !== gdkmonitor.get_connector())
    .map((monitor) => <GlobalMenuCloseLayer gdkmonitor={monitor} />)
}

function renderShutdownConfirmationOverlay(gdkmonitor: Gdk.Monitor) {
  const confirmShutdownAction = (action: ShutdownConfirmationAction) => {
    closeShutdownConfirmation()
    executeShutdownConfirmationAction(action)
  }

  return (
    <ShutdownConfirmationOverlay
      gdkmonitor={gdkmonitor}
      type={activeShutdownConfirmationAction}
      visible={isShutdownConfirmationVisible}
      onCancel={closeShutdownConfirmation}
      onConfirm={confirmShutdownAction}
    />
  )
}

function renderComponent(
  id: LayoutComponentId,
  gdkmonitor: Gdk.Monitor,
): JSX.Element | JSX.Element[] {
  switch (id) {
    case "app-launcher-menu":
      return <AppLauncherMenu gdkmonitor={gdkmonitor} />
    case "feed-hub-menu":
      return <FeedHubMenu gdkmonitor={gdkmonitor} />
    case "global-menu-close-layer":
      return renderCloseLayers(gdkmonitor)
    case "shutdown-confirmation-overlay":
      return renderShutdownConfirmationOverlay(gdkmonitor)
    case "system-controls-menu":
      return <SystemControlsMenu gdkmonitor={gdkmonitor} />
    case "system-controls-volume-osd":
      return <VolumeOsd gdkmonitor={gdkmonitor} />
  }
}

function renderLayout(
  layout: LayoutDefinition,
): Array<JSX.Element | JSX.Element[]> {
  const gdkmonitor = toGdkMonitor(layout.monitor)

  if (!gdkmonitor) {
    console.error(`Layout monitor not found: ${layout.monitor}`)
    return []
  }

  return [
    <Bar
      gdkmonitor={gdkmonitor}
      widgets={{
        left: renderWidgets(layout.widgets?.left, layout.monitor),
        center: renderWidgets(layout.widgets?.center, layout.monitor),
        right: renderWidgets(layout.widgets?.right, layout.monitor),
      }}
    />,
    ...(layout.components?.map((id) => renderComponent(id, gdkmonitor)) ?? []),
  ]
}

export default function Layout() {
  return [
    ...layoutConfig.layouts.flatMap(renderLayout),
    <NotificationPopups />,
  ]
}
