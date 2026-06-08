import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import { activeMenu } from "../../../global-store"
import {
  dismissNotification,
  fetchNotification,
  getNotificationDaemon,
  invokeNotificationAction,
  type NotificationSnapshot,
} from "../../../../utils/notification"
import { FEED_HUB_MENU_ID } from "../store"
import { notificationPopupsConfig } from "./config"

export type NotificationPopupSnapshot = {
  id: number
  notification: NotificationSnapshot
}

type NotificationPopupStore = {
  popups: Accessor<NotificationPopupSnapshot[]>
  clear: () => void
  dismiss: (id: number) => void
  invokeAction: (id: number, actionId: string) => void
  remove: (id: number) => void
  dispose: () => void
}

function samePopupSnapshots(
  prev: NotificationPopupSnapshot[],
  next: NotificationPopupSnapshot[],
) {
  return JSON.stringify(prev) === JSON.stringify(next)
}

function isFeedHubOpen() {
  return activeMenu.peek() === FEED_HUB_MENU_ID
}

function createNotificationPopupStore(): NotificationPopupStore {
  const notifd = getNotificationDaemon()
  const [popups, setPopups] = createState<NotificationPopupSnapshot[]>([], {
    equals: samePopupSnapshots,
  })
  const timeoutIds = new Map<number, number>()

  function clearTimeoutFor(id: number) {
    const timeoutId = timeoutIds.get(id)

    if (timeoutId === undefined) return

    GLib.source_remove(timeoutId)
    timeoutIds.delete(id)
  }

  function remove(id: number) {
    clearTimeoutFor(id)
    setPopups((current) => current.filter((popup) => popup.id !== id))
  }

  function scheduleTimeout(id: number) {
    clearTimeoutFor(id)

    const timeoutId = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      notificationPopupsConfig.timeoutMs,
      () => {
        timeoutIds.delete(id)
        setPopups((current) => current.filter((popup) => popup.id !== id))
        return GLib.SOURCE_REMOVE
      },
    )

    timeoutIds.set(id, timeoutId)
  }

  function push(notification: NotificationSnapshot) {
    if (isFeedHubOpen()) return

    scheduleTimeout(notification.id)
    setPopups((current) => {
      const next = [
        {
          id: notification.id,
          notification,
        },
        ...current.filter((popup) => popup.id !== notification.id),
      ].slice(0, notificationPopupsConfig.maxVisible)
      const visibleIds = new Set(next.map((popup) => popup.id))

      for (const id of Array.from(timeoutIds.keys())) {
        if (!visibleIds.has(id)) {
          clearTimeoutFor(id)
        }
      }

      return next
    })
  }

  function refetchNotification(id: number) {
    if (isFeedHubOpen()) return

    let notification: NotificationSnapshot | null = null

    try {
      notification = fetchNotification(id)
    } catch (error) {
      console.error(`Failed to fetch notification popup ${id}`, error)
      return
    }

    if (!notification) return

    push(notification)
  }

  function clear() {
    for (const id of Array.from(timeoutIds.keys())) {
      clearTimeoutFor(id)
    }

    setPopups([])
  }

  function dismiss(id: number) {
    remove(id)
    dismissNotification(id)
  }

  function invokeAction(id: number, actionId: string) {
    if (invokeNotificationAction(id, actionId)) {
      remove(id)
      return
    }

    refetchNotification(id)
  }

  const notifiedSignalId = notifd.connect("notified", (_notifd, id) => {
    refetchNotification(id)
  })
  const resolvedSignalId = notifd.connect("resolved", (_notifd, id) => {
    remove(id)
  })
  const activeMenuUnsubscribe = activeMenu.subscribe(() => {
    if (isFeedHubOpen()) {
      clear()
    }
  })

  function dispose() {
    notifd.disconnect(notifiedSignalId)
    notifd.disconnect(resolvedSignalId)
    activeMenuUnsubscribe()
    clear()
  }

  return {
    popups,
    clear,
    dismiss,
    invokeAction,
    remove,
    dispose,
  }
}

export const notificationPopupStore = createNotificationPopupStore()
export const notificationPopups = notificationPopupStore.popups
export const hasNotificationPopups = notificationPopups.as(
  (items) => items.length > 0,
)
export const clearNotificationPopups = notificationPopupStore.clear
export const dismissNotificationPopup = notificationPopupStore.dismiss
export const invokeNotificationPopupAction =
  notificationPopupStore.invokeAction
export const removeNotificationPopup = notificationPopupStore.remove
export const disposeNotificationPopupStore = notificationPopupStore.dispose
