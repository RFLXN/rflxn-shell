import { onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import { Gtk } from "ags/gtk4"
import NotificationItem from "./item"
import { notifications } from "./store"
import type { NotificationSnapshot } from "../../../../utils/notification"

type NotificationListEntry = {
  snapshot: NotificationSnapshot
  widget: Gtk.Widget
}

function sameNotificationSnapshot(
  prev: NotificationSnapshot,
  next: NotificationSnapshot,
) {
  return JSON.stringify(prev) === JSON.stringify(next)
}

function createNotificationWidget(notification: NotificationSnapshot) {
  return (<NotificationItem notification={notification} />) as Gtk.Widget
}

function getVerticalAdjustment(widget: Gtk.Widget) {
  const scrolledWindow = widget.get_ancestor(
    Gtk.ScrolledWindow.$gtype,
  ) as Gtk.ScrolledWindow | null

  return scrolledWindow?.get_vadjustment() ?? null
}

function clampAdjustmentValue(adjustment: Gtk.Adjustment, value: number) {
  const lower = adjustment.get_lower()
  const upper = adjustment.get_upper()
  const pageSize = adjustment.get_page_size()
  const max = Math.max(lower, upper - pageSize)

  return Math.min(Math.max(value, lower), max)
}

function createScrollPositionRestorer(widget: Gtk.Widget) {
  const adjustment = getVerticalAdjustment(widget)

  if (!adjustment) {
    return () => {}
  }

  const value = adjustment.get_value()
  const restore = () => {
    adjustment.set_value(clampAdjustmentValue(adjustment, value))

    return GLib.SOURCE_REMOVE
  }

  return () => {
    restore()
    GLib.idle_add(GLib.PRIORITY_HIGH_IDLE, restore)
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, restore)
  }
}

function reconcileNotificationWidgets(
  container: Gtk.Box,
  entries: Map<number, NotificationListEntry>,
  nextNotifications: NotificationSnapshot[],
) {
  const restoreScrollPosition = createScrollPositionRestorer(container)
  const nextIds = new Set(nextNotifications.map((notification) => notification.id))

  for (const [id, entry] of entries) {
    if (nextIds.has(id)) continue

    container.remove(entry.widget)
    entries.delete(id)
  }

  let previous: Gtk.Widget | null = null

  for (const notification of nextNotifications) {
    const entry = entries.get(notification.id)
    let widget: Gtk.Widget

    if (!entry) {
      widget = createNotificationWidget(notification)
      entries.set(notification.id, { snapshot: notification, widget })
      container.insert_child_after(widget, previous)
    } else if (!sameNotificationSnapshot(entry.snapshot, notification)) {
      const updatedWidget = createNotificationWidget(notification)

      container.remove(entry.widget)
      container.insert_child_after(updatedWidget, previous)
      entries.set(notification.id, {
        snapshot: notification,
        widget: updatedWidget,
      })
      widget = updatedWidget
    } else {
      widget = entry.widget

      if (widget.get_prev_sibling() !== previous) {
        container.reorder_child_after(widget, previous)
      }
    }

    previous = widget
  }

  restoreScrollPosition()
}

export default function NotificationList() {
  return (
    <box
      class="widget-feed-hub-notification-list"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      halign={Gtk.Align.FILL}
      $={(self) => {
        const entries = new Map<number, NotificationListEntry>()
        const reconcile = () => {
          reconcileNotificationWidgets(self, entries, notifications.peek())
        }
        const unsubscribe = notifications.subscribe(reconcile)

        reconcile()

        onCleanup(() => {
          unsubscribe()

          for (const entry of entries.values()) {
            self.remove(entry.widget)
          }

          entries.clear()
        })
      }}
    >
    </box>
  )
}
