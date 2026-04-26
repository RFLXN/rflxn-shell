import GLib from "gi://GLib?version=2.0"
import Pango from "gi://Pango?version=1.0"
import { Gtk } from "ags/gtk4"
import AppIcon from "../../../app-icon"
import Icon from "../../../icon"
import type {
  NotificationActionSnapshot,
  NotificationSnapshot,
} from "../../../../utils/notification"
import {
  dismissFeedHubNotification,
  invokeFeedHubNotificationAction,
} from "./store"

const NOTIFICATION_APP_ICON_SIZE = 14
const NOTIFICATION_DISMISS_CELL_SIZE = 22
const RELATIVE_TIME_LIMIT_SECONDS = 3 * 60 * 60
const NOTIFICATION_TEXT_WIDTH_CHARS = 42

type NotificationItemProps = {
  notification: NotificationSnapshot
}

function normalizeUnixTimeSeconds(time: number) {
  if (time > 10_000_000_000) {
    return Math.floor(time / 1000)
  }

  return Math.floor(time)
}

function getElapsedSeconds(time: number) {
  const timestamp = normalizeUnixTimeSeconds(time)
  const now = GLib.DateTime.new_now_local().to_unix()

  return Math.max(0, now - timestamp)
}

function pluralize(value: number, unit: string) {
  return `${value} ${unit}${value === 1 ? "" : "s"} ago`
}

function formatNotificationTime(time: number) {
  const timestamp = normalizeUnixTimeSeconds(time)
  const elapsedSeconds = getElapsedSeconds(time)

  if (elapsedSeconds < 60) {
    return pluralize(elapsedSeconds, "second")
  }

  if (elapsedSeconds < 60 * 60) {
    return pluralize(Math.floor(elapsedSeconds / 60), "minute")
  }

  if (elapsedSeconds <= RELATIVE_TIME_LIMIT_SECONDS) {
    return pluralize(Math.floor(elapsedSeconds / (60 * 60)), "hour")
  }

  return (
    GLib.DateTime.new_from_unix_local(timestamp).format("%Y-%m-%d %H:%M") ??
    ""
  )
}

function bindNotificationTimeLabel(label: Gtk.Label, time: number) {
  let timeoutId = 0
  let rootSignalId = 0

  const update = () => {
    label.set_label(formatNotificationTime(time))

    if (getElapsedSeconds(time) > RELATIVE_TIME_LIMIT_SECONDS) {
      timeoutId = 0
      return GLib.SOURCE_REMOVE
    }

    return GLib.SOURCE_CONTINUE
  }
  const cleanup = () => {
    if (timeoutId !== 0) {
      GLib.source_remove(timeoutId)
      timeoutId = 0
    }

    if (rootSignalId !== 0) {
      label.disconnect(rootSignalId)
      rootSignalId = 0
    }
  }

  if (update() === GLib.SOURCE_CONTINUE) {
    timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, update)
  }

  rootSignalId = label.connect("notify::root", () => {
    if (!label.get_root()) {
      cleanup()
    }
  })
}

function NotificationActionButton({
  action,
  notificationId,
}: {
  action: NotificationActionSnapshot
  notificationId: number
}) {
  const label = (
    <label
      class="widget-feed-hub-notification-action-label text"
      label={action.label || action.id}
      ellipsize={Pango.EllipsizeMode.END}
      maxWidthChars={18}
      xalign={0.5}
    />
  ) as Gtk.Widget

  return (
    <button
      class="widget-feed-hub-notification-action-button flat"
      hasFrame={false}
      focusable={false}
      focusOnClick={false}
      hexpand
      halign={Gtk.Align.FILL}
      child={label}
      $={(self) => {
        self.connect("clicked", () => {
          invokeFeedHubNotificationAction(notificationId, action.id)
        })
      }}
    />
  )
}

export default function NotificationItem({
  notification,
}: NotificationItemProps) {
  const appName =
    notification.appName || notification.desktopEntry || "Application"
  const title =
    notification.summary || "Notification"
  const actions = notification.actions.filter((action) => action.id)
  const appIcon = AppIcon({
    name: notification.appIcon || notification.desktopEntry,
    class: "widget-feed-hub-notification-app-icon",
    size: NOTIFICATION_APP_ICON_SIZE,
  })
  const dismissIcon = (
    <Icon
      name="close_small"
      class="widget-feed-hub-notification-dismiss-icon"
      size="css"
    />
  ) as Gtk.Widget
  const dismissContainer = (
    <centerbox
      class="widget-feed-hub-notification-dismiss-container"
      widthRequest={NOTIFICATION_DISMISS_CELL_SIZE}
      heightRequest={NOTIFICATION_DISMISS_CELL_SIZE}
      centerWidget={dismissIcon}
    />
  ) as Gtk.Widget
  const dismissButton = (
    <button
      class="widget-feed-hub-notification-dismiss-button flat"
      hasFrame={false}
      focusable={false}
      focusOnClick={false}
      valign={Gtk.Align.CENTER}
      child={dismissContainer}
      $={(self) => {
        self.connect("clicked", () => {
          dismissFeedHubNotification(notification.id)
        })
      }}
    />
  ) as Gtk.Widget
  const content = (
    <box
      class={`widget-feed-hub-notification is-${notification.urgency}`}
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      halign={Gtk.Align.FILL}
    >
      <box
        class="widget-feed-hub-notification-app"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={6}
      >
        {appIcon}
        <label
          class="widget-feed-hub-notification-app-name text"
          label={appName}
          ellipsize={Pango.EllipsizeMode.END}
          hexpand
          maxWidthChars={NOTIFICATION_TEXT_WIDTH_CHARS}
          xalign={0}
        />
        {dismissButton}
      </box>
      <label
        class="widget-feed-hub-notification-title text"
        label={title}
        hexpand
        halign={Gtk.Align.FILL}
        maxWidthChars={NOTIFICATION_TEXT_WIDTH_CHARS}
        wrapMode={Pango.WrapMode.WORD_CHAR}
        xalign={0}
        wrap
      />
      <label
        class="widget-feed-hub-notification-body text"
        label={notification.body}
        visible={notification.body.length > 0}
        hexpand
        halign={Gtk.Align.FILL}
        maxWidthChars={NOTIFICATION_TEXT_WIDTH_CHARS}
        wrapMode={Pango.WrapMode.WORD_CHAR}
        xalign={0}
        wrap
      />
      <box
        class="widget-feed-hub-notification-actions"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={6}
        visible={actions.length > 0}
      >
        {actions.map((action) => (
          <NotificationActionButton
            action={action}
            notificationId={notification.id}
          />
        ))}
      </box>
      <label
        class="widget-feed-hub-notification-time text"
        xalign={1}
        $={(self) => bindNotificationTimeLabel(self, notification.time)}
      />
    </box>
  ) as Gtk.Widget

  return content
}
