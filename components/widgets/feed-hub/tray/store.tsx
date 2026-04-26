import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalTray from "gi://AstalTray?version=0.1"

type FeedHubTrayStore = {
  items: Accessor<AstalTray.TrayItem[]>
  refetch: () => void
  dispose: () => void
}

const TRAY_REFRESH_SIGNALS = [
  "notify::items",
  "notify::items-model",
] as const

const BOOTSTRAP_REFETCH_DELAYS = [250, 1000] as const

function sameTrayItems(
  prev: AstalTray.TrayItem[],
  next: AstalTray.TrayItem[],
) {
  return prev.length === next.length && prev.every((item, i) => item === next[i])
}

function getTrayItemId(item: AstalTray.TrayItem) {
  try {
    return item.get_item_id()
  } catch {
    return ""
  }
}

function createFeedHubTrayStore(): FeedHubTrayStore {
  const tray = AstalTray.get_default()
  const [items, setItems] = createState<AstalTray.TrayItem[]>([], {
    equals: sameTrayItems,
  })
  const traySignalIds = TRAY_REFRESH_SIGNALS.map((signal) =>
    tray.connect(signal, () => queueRefetch()),
  )
  const itemAddedSignalId = tray.connect("item-added", (_tray, itemId) => {
    addItem(itemId)
  })
  const itemRemovedSignalId = tray.connect("item-removed", (_tray, itemId) => {
    removeItem(itemId)
  })
  let idleId = 0
  const timeoutIds = new Set<number>()
  let disposed = false

  function getCurrentItems() {
    return tray.get_items().filter(Boolean)
  }

  function refetchNow() {
    try {
      setItems(getCurrentItems())
    } catch (error) {
      console.error("Failed to fetch system tray items", error)
    }
  }

  function addItem(itemId: string) {
    try {
      const item = tray.get_item(itemId)

      if (!item) return

      setItems((current) => {
        if (current.some((existing) => getTrayItemId(existing) === itemId)) {
          return current
        }

        return [...current, item]
      })
    } catch (error) {
      console.error("Failed to add system tray item", error)
    }
  }

  function removeItem(itemId: string) {
    setItems((current) =>
      current.filter((item) => getTrayItemId(item) !== itemId),
    )
  }

  function queueRefetch() {
    if (disposed || idleId !== 0) {
      return
    }

    idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      idleId = 0
      refetchNow()
      return GLib.SOURCE_REMOVE
    })
  }

  function dispose() {
    disposed = true

    if (idleId !== 0) {
      GLib.source_remove(idleId)
      idleId = 0
    }

    for (const id of traySignalIds) {
      tray.disconnect(id)
    }

    tray.disconnect(itemAddedSignalId)
    tray.disconnect(itemRemovedSignalId)

    for (const id of timeoutIds) {
      GLib.source_remove(id)
    }

    timeoutIds.clear()
  }

  queueRefetch()
  for (const delay of BOOTSTRAP_REFETCH_DELAYS) {
    const timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delay, () => {
      timeoutIds.delete(timeoutId)
      queueRefetch()
      return GLib.SOURCE_REMOVE
    })

    timeoutIds.add(timeoutId)
  }

  return {
    items,
    refetch: queueRefetch,
    dispose,
  }
}

export const feedHubTrayStore = createFeedHubTrayStore()
export const trayItems = feedHubTrayStore.items
export const refetchTrayItems = feedHubTrayStore.refetch
export const disposeFeedHubTrayStore = feedHubTrayStore.dispose
