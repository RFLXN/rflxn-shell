import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalHyprland from "gi://AstalHyprland?version=0.1"
import {
  fetchHyprlandWorkspaces,
  type HyprlandWindowSnapshot,
  type HyprlandWorkspaceSnapshot,
} from "../../../utils/hyprland/workspaces"
import {
  fetchXWaylandUrgentWindowAddresses,
} from "../../../utils/xwayland-urgency"

type HyprlandStore = {
  workspaces: Accessor<HyprlandWorkspaceSnapshot[]>
  refetch: () => void
  dispose: () => void
}

const HYPRLAND_REFRESH_SIGNALS = [
  "workspace-added",
  "workspace-removed",
  "client-added",
  "client-removed",
  "client-moved",
  "monitor-added",
  "monitor-removed",
  "minimize",
  "floating",
  "notify::workspaces",
  "notify::clients",
  "notify::monitors",
  "notify::focused-workspace",
  "notify::focused-monitor",
  "notify::focused-client",
] as const

const CLIENT_REFRESH_SIGNALS = [
  "removed",
  "moved-to",
  "notify::mapped",
  "notify::hidden",
  "notify::workspace",
  "notify::monitor",
  "notify::class",
  "notify::title",
  "notify::initial-class",
  "notify::initial-title",
  "notify::pid",
  "notify::xwayland",
] as const

const XWAYLAND_URGENCY_POLL_INTERVAL_MS = 1000

function sameWorkspaceSnapshots(
  prev: HyprlandWorkspaceSnapshot[],
  next: HyprlandWorkspaceSnapshot[],
) {
  return JSON.stringify(prev) === JSON.stringify(next)
}

function getFocusedWindowFromWorkspaces(workspaceItems: HyprlandWorkspaceSnapshot[]) {
  return (
    workspaceItems
      .flatMap((workspace) => workspace.windows)
      .find((window) => window.status === "focused") ?? null
  )
}

function sameStringSet(left: ReadonlySet<string>, right: ReadonlySet<string>) {
  if (left.size !== right.size) return false

  for (const value of left) {
    if (!right.has(value)) return false
  }

  return true
}

function replaceStringSet(target: Set<string>, source: ReadonlySet<string>) {
  target.clear()

  for (const value of source) {
    target.add(value)
  }
}

function createHyprlandStore(): HyprlandStore {
  const hyprland = AstalHyprland.get_default()
  const [workspaces, setWorkspaces] = createState<
    HyprlandWorkspaceSnapshot[]
  >([], {
    equals: sameWorkspaceSnapshots,
  })
  const hyprlandSignalIds = HYPRLAND_REFRESH_SIGNALS.map((signal) =>
    hyprland.connect(signal, () => queueRefetch()),
  )
  const urgentWindowAddresses = new Set<string>()
  const xwaylandUrgentWindowAddresses = new Set<string>()
  const acknowledgedXWaylandUrgentWindowAddresses = new Set<string>()
  const urgentSignalId = hyprland.connect("urgent", (_hyprland, client) => {
    const address = client.get_address()

    if (address) {
      urgentWindowAddresses.add(address)
    }

    queueRefetch()
  })
  const clientSignalIds = new Map<
    string,
    { client: AstalHyprland.Client; ids: number[] }
  >()
  let idleId = 0
  let xwaylandUrgencyPollId = 0
  let fetching = false
  let pendingRefetch = false
  let disposed = false

  function syncClientSignals() {
    const activeAddresses = new Set<string>()

    for (const client of hyprland.get_clients()) {
      const address = client.get_address()
      activeAddresses.add(address)

      if (clientSignalIds.has(address)) {
        continue
      }

      clientSignalIds.set(address, {
        client,
        ids: CLIENT_REFRESH_SIGNALS.map((signal) =>
          client.connect(signal, () => queueRefetch()),
        ),
      })
    }

    for (const [address, subscription] of clientSignalIds) {
      if (activeAddresses.has(address)) {
        continue
      }

      for (const id of subscription.ids) {
        subscription.client.disconnect(id)
      }

      clientSignalIds.delete(address)
    }
  }

  function syncUrgentWindowAddresses(
    workspaceItems: HyprlandWorkspaceSnapshot[],
  ) {
    const activeWindowAddresses = new Set<string>()

    for (const workspace of workspaceItems) {
      for (const window of workspace.windows) {
        activeWindowAddresses.add(window.address)

        if (workspace.status === "focused") {
          urgentWindowAddresses.delete(window.address)

          if (xwaylandUrgentWindowAddresses.has(window.address)) {
            acknowledgedXWaylandUrgentWindowAddresses.add(window.address)
          }

          xwaylandUrgentWindowAddresses.delete(window.address)
        }
      }
    }

    for (const address of urgentWindowAddresses) {
      if (!activeWindowAddresses.has(address)) {
        urgentWindowAddresses.delete(address)
      }
    }

    for (const address of xwaylandUrgentWindowAddresses) {
      if (!activeWindowAddresses.has(address)) {
        xwaylandUrgentWindowAddresses.delete(address)
      }
    }

    for (const address of acknowledgedXWaylandUrgentWindowAddresses) {
      if (!activeWindowAddresses.has(address)) {
        acknowledgedXWaylandUrgentWindowAddresses.delete(address)
      }
    }
  }

  function getUrgentWindowAddresses() {
    return new Set([
      ...urgentWindowAddresses,
      ...xwaylandUrgentWindowAddresses,
    ])
  }

  function syncXWaylandUrgentWindowAddresses() {
    const next = fetchXWaylandUrgentWindowAddresses(hyprland.get_clients())

    for (const address of acknowledgedXWaylandUrgentWindowAddresses) {
      if (next.has(address)) {
        next.delete(address)
      } else {
        acknowledgedXWaylandUrgentWindowAddresses.delete(address)
      }
    }

    if (sameStringSet(xwaylandUrgentWindowAddresses, next)) {
      return false
    }

    replaceStringSet(xwaylandUrgentWindowAddresses, next)
    return true
  }

  function pollXWaylandUrgency() {
    if (disposed) {
      xwaylandUrgencyPollId = 0
      return GLib.SOURCE_REMOVE
    }

    try {
      if (syncXWaylandUrgentWindowAddresses()) {
        queueRefetch()
      }
    } catch (error) {
      console.error("Failed to poll XWayland urgent window state", error)
    }

    return GLib.SOURCE_CONTINUE
  }

  async function refetchNow() {
    if (disposed) return

    if (fetching) {
      pendingRefetch = true
      return
    }

    fetching = true

    try {
      do {
        pendingRefetch = false
        syncClientSignals()
        syncXWaylandUrgentWindowAddresses()

        const next = await fetchHyprlandWorkspaces({
          urgentWindowAddresses: getUrgentWindowAddresses(),
        })

        if (disposed) {
          return
        }

        syncUrgentWindowAddresses(next)
        setWorkspaces(next)
        syncClientSignals()
      } while (pendingRefetch && !disposed)
    } catch (error) {
      console.error("Failed to fetch Hyprland workspace state", error)
    } finally {
      fetching = false
    }
  }

  function queueRefetch() {
    if (disposed || idleId !== 0) {
      return
    }

    idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      idleId = 0
      void refetchNow()
      return GLib.SOURCE_REMOVE
    })
  }

  function dispose() {
    disposed = true

    if (idleId !== 0) {
      GLib.source_remove(idleId)
      idleId = 0
    }

    if (xwaylandUrgencyPollId !== 0) {
      GLib.source_remove(xwaylandUrgencyPollId)
      xwaylandUrgencyPollId = 0
    }

    for (const id of hyprlandSignalIds) {
      hyprland.disconnect(id)
    }

    hyprland.disconnect(urgentSignalId)

    for (const subscription of clientSignalIds.values()) {
      for (const id of subscription.ids) {
        subscription.client.disconnect(id)
      }
    }

    clientSignalIds.clear()
  }

  queueRefetch()
  xwaylandUrgencyPollId = GLib.timeout_add(
    GLib.PRIORITY_DEFAULT,
    XWAYLAND_URGENCY_POLL_INTERVAL_MS,
    pollXWaylandUrgency,
  )

  return {
    workspaces,
    refetch: queueRefetch,
    dispose,
  }
}

export const hyprlandStore = createHyprlandStore()
export const workspaces = hyprlandStore.workspaces
export const focusedWindow: Accessor<HyprlandWindowSnapshot | null> = workspaces.as(
  getFocusedWindowFromWorkspaces,
)
export const focusedWindowTitle = focusedWindow.as((window) => window?.name ?? "")
export const refetchHyprland = hyprlandStore.refetch
export const disposeHyprlandStore = hyprlandStore.dispose
