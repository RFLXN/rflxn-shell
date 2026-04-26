import type AstalHyprland from "gi://AstalHyprland?version=0.1"
import app from "ags/gtk4/app"
import { Gdk } from "ags/gtk4"

export type MonitorLike =
  | AstalHyprland.Monitor
  | Gdk.Monitor
  | string
  | null
  | undefined

export function toGdkMonitor(monitor: MonitorLike): Gdk.Monitor | null {
  if (monitor == null) {
    return null
  }

  if (monitor instanceof Gdk.Monitor) {
    return monitor
  }

  const connector =
    typeof monitor === "string" ? monitor : monitor.get_name()

  if (!connector) {
    return null
  }

  return (
    app.get_monitors().find((candidate) => {
      return candidate.get_connector() === connector
    }) ?? null
  )
}
