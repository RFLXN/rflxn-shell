import { For, onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import type Gdk from "gi://Gdk?version=4.0"
import Gtk4LayerShell from "gi://Gtk4LayerShell?version=1.0"
import Pango from "gi://Pango?version=1.0"
import { Astal, Gtk } from "ags/gtk4"
import { barExclusiveZone } from "../../../bar/store"
import AppIcon from "../../../app-icon"
import Icon from "../../../icon"
import { toGdkMonitor } from "../../../../utils/monitor"
import type {
  NotificationActionSnapshot,
  NotificationSnapshot,
} from "../../../../utils/notification"
import {
  notificationPopupsConfig,
  type NotificationPopupPosition,
} from "./config"
import {
  dismissNotificationPopup,
  hasNotificationPopups,
  invokeNotificationPopupAction,
  notificationPopups,
} from "./store"

type NotificationPopupItemProps = {
  notification: NotificationSnapshot
}

const NOTIFICATION_POPUP_MARGIN = 8
const NOTIFICATION_POPUP_WIDTH = 392
const NOTIFICATION_POPUP_TEXT_WIDTH_CHARS = 42
const NOTIFICATION_POPUP_DISMISS_CELL_SIZE = 22
const NOTIFICATION_POPUP_ACTION_WIDTH_CHARS = 18

function isTopPosition(position: NotificationPopupPosition) {
  return position.startsWith("top-")
}

function isLeftPosition(position: NotificationPopupPosition) {
  return position.endsWith("-left")
}

function getWindowAnchor(position: NotificationPopupPosition) {
  return (
    (isTopPosition(position)
      ? Astal.WindowAnchor.TOP
      : Astal.WindowAnchor.BOTTOM) |
    (isLeftPosition(position)
      ? Astal.WindowAnchor.LEFT
      : Astal.WindowAnchor.RIGHT)
  )
}

function getHorizontalAlign(position: NotificationPopupPosition) {
  return isLeftPosition(position) ? Gtk.Align.START : Gtk.Align.END
}

function getVerticalAlign(position: NotificationPopupPosition) {
  return isTopPosition(position) ? Gtk.Align.START : Gtk.Align.END
}

function orderPopupsForPosition<T>(
  items: T[],
  position: NotificationPopupPosition,
) {
  return isTopPosition(position) ? items : items.slice().reverse()
}

function NotificationPopupActionButton({
  action,
  notificationId,
}: {
  action: NotificationActionSnapshot
  notificationId: number
}) {
  return (
    <button
      class="widget-feed-hub-notification-action-button widget-feed-hub-notification-popup-action-button flat"
      hasFrame={false}
      focusable={false}
      focusOnClick={false}
      hexpand
      halign={Gtk.Align.FILL}
      child={(
        <label
          class="widget-feed-hub-notification-action-label text"
          label={action.label || action.id}
          ellipsize={Pango.EllipsizeMode.END}
          maxWidthChars={NOTIFICATION_POPUP_ACTION_WIDTH_CHARS}
          xalign={0.5}
        />
      ) as Gtk.Widget}
      $={(self) => {
        self.connect("clicked", () => {
          invokeNotificationPopupAction(notificationId, action.id)
        })
      }}
    />
  )
}

function NotificationPopupItem({
  notification,
}: NotificationPopupItemProps) {
  const appName =
    notification.appName || notification.desktopEntry || "Application"
  const title = notification.summary || "Notification"
  const actions = notification.actions.filter((action) => action.id)
  const appIcon = AppIcon({
    name: notification.appIcon || notification.desktopEntry,
    class: "widget-feed-hub-notification-app-icon",
    size: 14,
  })
  const dismissButton = (
    <button
      class="widget-feed-hub-notification-dismiss-button flat"
      hasFrame={false}
      focusable={false}
      focusOnClick={false}
      valign={Gtk.Align.CENTER}
      child={(
        <centerbox
          class="widget-feed-hub-notification-dismiss-container"
          widthRequest={NOTIFICATION_POPUP_DISMISS_CELL_SIZE}
          heightRequest={NOTIFICATION_POPUP_DISMISS_CELL_SIZE}
          centerWidget={(
            <Icon
              name="close_small"
              class="widget-feed-hub-notification-dismiss-icon"
              size="css"
            />
          ) as Gtk.Widget}
        />
      ) as Gtk.Widget}
      $={(self) => {
        self.connect("clicked", () => {
          dismissNotificationPopup(notification.id)
        })
      }}
    />
  ) as Gtk.Widget

  return (
    <box
      class={`widget-feed-hub-notification widget-feed-hub-notification-popup is-${notification.urgency}`}
      orientation={Gtk.Orientation.VERTICAL}
      widthRequest={NOTIFICATION_POPUP_WIDTH}
      hexpand
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
          maxWidthChars={NOTIFICATION_POPUP_TEXT_WIDTH_CHARS}
          xalign={0}
        />
        {dismissButton}
      </box>
      <label
        class="widget-feed-hub-notification-title text"
        label={title}
        hexpand
        halign={Gtk.Align.FILL}
        maxWidthChars={NOTIFICATION_POPUP_TEXT_WIDTH_CHARS}
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
        maxWidthChars={NOTIFICATION_POPUP_TEXT_WIDTH_CHARS}
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
          <NotificationPopupActionButton
            action={action}
            notificationId={notification.id}
          />
        ))}
      </box>
    </box>
  )
}

export default function NotificationPopups() {
  const configuredMonitor = toGdkMonitor(notificationPopupsConfig.monitor)

  if (!configuredMonitor) {
    console.error(
      `Notification popup monitor not found: ${notificationPopupsConfig.monitor}`,
    )
    return null
  }

  const monitorProps = { gdkmonitor: configuredMonitor as Gdk.Monitor }
  const position = notificationPopupsConfig.position
  const stack = (
    <box
      class={`widget-feed-hub-notification-popup-stack is-${position}`}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
      halign={getHorizontalAlign(position)}
      valign={getVerticalAlign(position)}
    >
      <For each={notificationPopups.as((items) =>
        orderPopupsForPosition(items, position),
      )}>
        {(popup) => (
          <NotificationPopupItem notification={popup.notification} />
        )}
      </For>
    </box>
  ) as Gtk.Widget

  return (
    <window
      {...monitorProps}
      name="notification-popups"
      namespace="notification-popups"
      class="widget-feed-hub-notification-popup-window"
      visible={hasNotificationPopups}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.NONE}
      anchor={getWindowAnchor(position)}
      $={(self) => {
        const updateLayerMargins = () => {
          const topMargin = isTopPosition(position)
            ? barExclusiveZone.peek() + NOTIFICATION_POPUP_MARGIN
            : NOTIFICATION_POPUP_MARGIN

          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.TOP,
            topMargin,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.RIGHT,
            NOTIFICATION_POPUP_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.BOTTOM,
            NOTIFICATION_POPUP_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.LEFT,
            NOTIFICATION_POPUP_MARGIN,
          )
        }
        const queueLayerMarginUpdate = () => {
          GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            updateLayerMargins()
            return GLib.SOURCE_REMOVE
          })
        }

        queueLayerMarginUpdate()
        self.connect("map", queueLayerMarginUpdate)
        onCleanup(barExclusiveZone.subscribe(queueLayerMarginUpdate))
      }}
    >
      {stack}
    </window>
  )
}
