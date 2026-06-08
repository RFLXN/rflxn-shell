import { createState, type Accessor } from "ags"
import type AstalNotifd from "gi://AstalNotifd?version=0.1"
import GLib from "gi://GLib?version=2.0"
import {
  dismissAllNotifications,
  dismissNotification,
  fetchNotification,
  fetchNotifications,
  getNotificationDaemon,
  invokeNotificationAction,
  type NotificationSnapshot,
} from "../../../../utils/notification"

type FeedHubNotificationStore = {
  notifications: Accessor<NotificationSnapshot[]>
  dismiss: (id: number) => void
  dismissAll: () => void
  invokeAction: (id: number, actionId: string) => void
  refetch: () => void
  dispose: () => void
}

const NOTIFICATION_REFRESH_SIGNALS = [
  "notify::notifications",
] as const

const NOTIFICATION_ITEM_REFRESH_SIGNALS = [
  "resolved",
  "invoked",
  "notify::state",
  "notify::app-name",
  "notify::app-icon",
  "notify::summary",
  "notify::body",
  "notify::expire-timeout",
  "notify::actions",
  "notify::image",
  "notify::category",
  "notify::desktop-entry",
  "notify::resident",
  "notify::transient",
  "notify::urgency",
] as const

function sameNotificationSnapshots(
  prev: NotificationSnapshot[],
  next: NotificationSnapshot[],
) {
  return JSON.stringify(prev) === JSON.stringify(next)
}

function sameNotificationSnapshot(
  prev: NotificationSnapshot,
  next: NotificationSnapshot,
) {
  return JSON.stringify(prev) === JSON.stringify(next)
}

function reuseUnchangedNotificationSnapshots(
  prev: NotificationSnapshot[],
  next: NotificationSnapshot[],
) {
  const prevById = new Map(prev.map((notification) => [
    notification.id,
    notification,
  ]))

  return next.map((notification) => {
    const previous = prevById.get(notification.id)

    return previous && sameNotificationSnapshot(previous, notification)
      ? previous
      : notification
  })
}

function byNewestNotification(
  a: NotificationSnapshot,
  b: NotificationSnapshot,
) {
  return b.time - a.time || b.id - a.id
}

function sortNotificationSnapshots(notifications: NotificationSnapshot[]) {
  return notifications.slice().sort(byNewestNotification)
}

function createFeedHubNotificationStore(): FeedHubNotificationStore {
  const notifd = getNotificationDaemon()
  const [notifications, setNotifications] = createState<
    NotificationSnapshot[]
  >([], {
    equals: sameNotificationSnapshots,
  })
  const daemonSignalIds = NOTIFICATION_REFRESH_SIGNALS.map((signal) =>
    notifd.connect(signal, () => queueRefetch()),
  )
  const notifiedSignalId = notifd.connect("notified", (_notifd, id) => {
    refetchNotification(id)
  })
  const resolvedSignalId = notifd.connect("resolved", (_notifd, id) => {
    removeNotification(id)
  })
  const notificationSignalIds = new Map<
    number,
    { notification: AstalNotifd.Notification; ids: number[] }
  >()
  let idleId = 0
  let disposed = false

  function syncNotificationSignals() {
    const activeIds = new Set<number>()

    for (const notification of notifd.get_notifications()) {
      const id = notification.get_id()
      const subscription = notificationSignalIds.get(id)

      activeIds.add(id)

      if (subscription?.notification === notification) {
        continue
      }

      if (subscription) {
        for (const signalId of subscription.ids) {
          subscription.notification.disconnect(signalId)
        }

        notificationSignalIds.delete(id)
      }

      notificationSignalIds.set(id, {
        notification,
        ids: connectNotificationSignals(notification),
      })
    }

    for (const [id, subscription] of notificationSignalIds) {
      if (activeIds.has(id)) {
        continue
      }

      for (const signalId of subscription.ids) {
        subscription.notification.disconnect(signalId)
      }

      notificationSignalIds.delete(id)
    }
  }

  function refetchNow() {
    try {
      setNotifications((prev) =>
        reuseUnchangedNotificationSnapshots(prev, fetchNotifications()),
      )
      syncNotificationSignals()
    } catch (error) {
      console.error("Failed to fetch notification state", error)
    }
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

  function connectNotificationSignals(
    notification: AstalNotifd.Notification,
  ) {
    const signalIds: number[] = []

    for (const signal of NOTIFICATION_ITEM_REFRESH_SIGNALS) {
      try {
        signalIds.push(notification.connect(signal, () => queueRefetch()))
      } catch (error) {
        console.error(`Failed to connect notification signal ${signal}`, error)
      }
    }

    return signalIds
  }

  function setOrderedNotifications(next: NotificationSnapshot[]) {
    setNotifications((prev) =>
      reuseUnchangedNotificationSnapshots(
        prev,
        sortNotificationSnapshots(next),
      ),
    )
  }

  function upsertNotification(notification: NotificationSnapshot) {
    setOrderedNotifications([
      notification,
      ...notifications.peek().filter((item) => item.id !== notification.id),
    ])

    try {
      syncNotificationSignals()
    } catch (error) {
      console.error("Failed to sync notification signals", error)
    }
  }

  function removeNotification(id: number) {
    const current = notifications.peek()

    if (!current.some((notification) => notification.id === id)) return

    setNotifications(current.filter((notification) => notification.id !== id))
  }

  function refetchNotification(id: number) {
    try {
      const notification = fetchNotification(id)

      if (notification) {
        upsertNotification(notification)
      } else {
        removeNotification(id)
      }
    } catch (error) {
      console.error(`Failed to fetch notification ${id}`, error)
      queueRefetch()
    }
  }

  function dismiss(id: number) {
    removeNotification(id)

    if (!dismissNotification(id)) {
      queueRefetch()
    }
  }

  function dismissAll() {
    const current = notifications.peek()

    if (current.length > 0) {
      setNotifications([])
    }

    if (dismissAllNotifications() === 0 && current.length > 0) {
      queueRefetch()
    }
  }

  function invokeAction(id: number, actionId: string) {
    const current = notifications.peek()
    const notification = current.find((item) => item.id === id)

    if (!invokeNotificationAction(id, actionId)) {
      queueRefetch()
      return
    }

    if (notification && !notification.resident) {
      setNotifications(current.filter((item) => item.id !== id))
      return
    }

    queueRefetch()
  }

  function dispose() {
    disposed = true

    if (idleId !== 0) {
      GLib.source_remove(idleId)
      idleId = 0
    }

    for (const signalId of daemonSignalIds) {
      notifd.disconnect(signalId)
    }

    notifd.disconnect(notifiedSignalId)
    notifd.disconnect(resolvedSignalId)

    for (const subscription of notificationSignalIds.values()) {
      for (const signalId of subscription.ids) {
        subscription.notification.disconnect(signalId)
      }
    }

    notificationSignalIds.clear()
  }

  queueRefetch()

  return {
    notifications,
    dismiss,
    dismissAll,
    invokeAction,
    refetch: queueRefetch,
    dispose,
  }
}

export const feedHubNotificationStore = createFeedHubNotificationStore()
export const notifications = feedHubNotificationStore.notifications
export const notificationCount = notifications.as((items) => items.length)
export const hasNotifications = notificationCount.as((count) => count > 0)
export const dismissAllFeedHubNotifications =
  feedHubNotificationStore.dismissAll
export const dismissFeedHubNotification = feedHubNotificationStore.dismiss
export const invokeFeedHubNotificationAction =
  feedHubNotificationStore.invokeAction
export const refetchNotifications = feedHubNotificationStore.refetch
export const disposeFeedHubNotificationStore =
  feedHubNotificationStore.dispose
