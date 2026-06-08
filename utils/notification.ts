import AstalNotifd from "gi://AstalNotifd?version=0.1"

export type NotificationUrgency = "low" | "normal" | "critical"

export type NotificationState = "draft" | "sent" | "received"

export type NotificationActionSnapshot = {
  id: string
  label: string
}

export type NotificationSnapshot = {
  id: number
  state: NotificationState
  appName: string
  appIcon: string
  summary: string
  body: string
  image: string
  category: string
  desktopEntry: string
  resident: boolean
  transient: boolean
  urgency: NotificationUrgency
  time: number
  expireTimeout: number
  actions: NotificationActionSnapshot[]
}

function getNotifd() {
  return AstalNotifd.get_default()
}

function toStringValue(value: string | null | undefined) {
  return typeof value === "string" ? value : ""
}

function toUrgency(urgency: AstalNotifd.Urgency): NotificationUrgency {
  switch (urgency) {
    case AstalNotifd.Urgency.LOW:
      return "low"
    case AstalNotifd.Urgency.CRITICAL:
      return "critical"
    case AstalNotifd.Urgency.NORMAL:
    default:
      return "normal"
  }
}

function toState(state: AstalNotifd.State): NotificationState {
  switch (state) {
    case AstalNotifd.State.DRAFT:
      return "draft"
    case AstalNotifd.State.SENT:
      return "sent"
    case AstalNotifd.State.RECEIVED:
    default:
      return "received"
  }
}

function toActionSnapshot(
  action: AstalNotifd.Action,
): NotificationActionSnapshot {
  return {
    id: toStringValue(action.get_id()),
    label: toStringValue(action.get_label()),
  }
}

function byNewestNotification(
  a: NotificationSnapshot,
  b: NotificationSnapshot,
) {
  return b.time - a.time || b.id - a.id
}

export function toNotificationSnapshot(
  notification: AstalNotifd.Notification,
): NotificationSnapshot {
  return {
    id: notification.get_id(),
    state: toState(notification.get_state()),
    appName: toStringValue(notification.get_app_name()),
    appIcon: toStringValue(notification.get_app_icon()),
    summary: toStringValue(notification.get_summary()),
    body: toStringValue(notification.get_body()),
    image: toStringValue(notification.get_image()),
    category: toStringValue(notification.get_category()),
    desktopEntry: toStringValue(notification.get_desktop_entry()),
    resident: notification.get_resident(),
    transient: notification.get_transient(),
    urgency: toUrgency(notification.get_urgency()),
    time: notification.get_time(),
    expireTimeout: notification.get_expire_timeout(),
    actions: notification.get_actions().map(toActionSnapshot),
  }
}

export function fetchNotifications(): NotificationSnapshot[] {
  return getNotifd()
    .get_notifications()
    .map(toNotificationSnapshot)
    .sort(byNewestNotification)
}

export function fetchNotification(id: number): NotificationSnapshot | null {
  const notification = getNotifd().get_notification(id)

  return notification ? toNotificationSnapshot(notification) : null
}

export function dismissNotification(id: number) {
  try {
    const notification = getNotifd().get_notification(id)

    if (!notification) return false

    notification.dismiss()
    return true
  } catch (error) {
    console.error(`Failed to dismiss notification ${id}`, error)
    return false
  }
}

export function dismissAllNotifications() {
  try {
    const notifications = getNotifd().get_notifications()

    for (const notification of notifications) {
      notification.dismiss()
    }

    return notifications.length
  } catch (error) {
    console.error("Failed to dismiss all notifications", error)
    return 0
  }
}

export function invokeNotificationAction(id: number, actionId: string) {
  try {
    const notification = getNotifd().get_notification(id)

    if (!notification || !actionId) return false

    notification.invoke(actionId)
    return true
  } catch (error) {
    console.error(`Failed to invoke notification ${id} action ${actionId}`, error)
    return false
  }
}

export function getNotificationDaemon() {
  return getNotifd()
}
