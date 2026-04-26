import { onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import type Gdk from "gi://Gdk?version=4.0"
import Gtk4LayerShell from "gi://Gtk4LayerShell?version=1.0"
import { Astal, Gtk } from "ags/gtk4"
import { barExclusiveZone } from "../../bar/store"
import { closeActiveMenu, closeGlobalMenus } from "../../global-store"
import { addCloseOnEscape } from "../../menu-escape"
import NotificationList from "./notification"
import TrayIconList from "./tray"
import {
  dismissAllFeedHubNotifications,
  hasNotifications,
} from "./notification/store"
import {
  FEED_HUB_MENU_TRANSITION_DURATION,
  isFeedHubMenuRevealed,
  isFeedHubMenuVisible,
} from "./store"

type FeedHubMenuProps = {
  gdkmonitor?: Gdk.Monitor
}

const FEED_HUB_MENU_MARGIN = 6
const FEED_HUB_SYSTRAY_HEIGHT = 30
const FEED_HUB_MENU_WIDTH = 450

function addPrimaryClick(widget: Gtk.Widget, onClick: () => void) {
  const click = Gtk.GestureClick.new()

  click.set_button(1)
  click.connect("released", (gesture, nPress) => {
    if (nPress !== 1) return

    gesture.set_state(Gtk.EventSequenceState.CLAIMED)
    onClick()
  })

  widget.add_controller(click)
}

function addOutsideClickCapture(widget: Gtk.Widget, onClick: () => void) {
  const click = Gtk.GestureClick.new()

  click.set_button(1)
  click.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
  click.connect("pressed", (gesture, nPress, x) => {
    if (nPress !== 1 || x < FEED_HUB_MENU_WIDTH) return

    gesture.set_state(Gtk.EventSequenceState.CLAIMED)
    onClick()
  })

  widget.add_controller(click)
}

export default function FeedHubMenu({ gdkmonitor }: FeedHubMenuProps) {
  const monitorProps = gdkmonitor ? { gdkmonitor } : {}
  const systrayContent = <TrayIconList /> as Gtk.Widget
  const systray = (
    <scrolledwindow
      class="widget-feed-hub-systray-scroll"
      heightRequest={FEED_HUB_SYSTRAY_HEIGHT}
      hexpand
      halign={Gtk.Align.FILL}
      propagateNaturalWidth={false}
      propagateNaturalHeight={false}
      child={systrayContent}
      $={(self) => {
        self.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER)
        self.set_overlay_scrolling(true)
      }}
    />
  ) as Gtk.Widget
  const divider = (
    <box class="widget-feed-hub-menu-divider" />
  ) as Gtk.Widget
  const dismissAllLabel = (
    <label
      class="widget-feed-hub-dismiss-all-label text"
      label="Dismiss All"
    />
  ) as Gtk.Widget
  const dismissAllButton = (
    <button
      class="widget-feed-hub-dismiss-all-button flat"
      hasFrame={false}
      focusable={false}
      focusOnClick={false}
      hexpand
      child={dismissAllLabel}
      $={(self) => {
        self.connect("clicked", dismissAllFeedHubNotifications)
      }}
    />
  ) as Gtk.Widget
  const notificationToolbar = (
    <box
      class="widget-feed-hub-notification-toolbar"
      orientation={Gtk.Orientation.HORIZONTAL}
      hexpand
      visible={hasNotifications}
    >
      {dismissAllButton}
    </box>
  ) as Gtk.Widget
  const notificationList = <NotificationList /> as Gtk.Widget
  const notificationArea = (
    <scrolledwindow
      class="widget-feed-hub-notification-scroll"
      hexpand
      halign={Gtk.Align.FILL}
      propagateNaturalWidth={false}
      vexpand
      visible={hasNotifications}
      child={notificationList}
      $={(self) => {
        self.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
      }}
    />
  ) as Gtk.Widget
  const emptyStateLabel = (
    <label
      class="widget-feed-hub-notification-empty-label text"
      label="No notifications"
    />
  ) as Gtk.Widget
  const emptyState = (
    <centerbox
      class="widget-feed-hub-notification-empty"
      hexpand
      vexpand
      visible={hasNotifications.as((hasItems) => !hasItems)}
      centerWidget={emptyStateLabel}
    />
  ) as Gtk.Widget
  const content = (
    <box
      class="widget-feed-hub-menu-content"
      canTarget={isFeedHubMenuRevealed}
      orientation={Gtk.Orientation.VERTICAL}
      overflow={Gtk.Overflow.HIDDEN}
      widthRequest={FEED_HUB_MENU_WIDTH}
      halign={Gtk.Align.START}
      vexpand
    >
      {systray}
      {divider}
      {notificationToolbar}
      {notificationArea}
      {emptyState}
    </box>
  ) as Gtk.Widget
  const revealer = (
    <revealer
      class="widget-feed-hub-menu-revealer"
      revealChild={isFeedHubMenuRevealed}
      transitionDuration={FEED_HUB_MENU_TRANSITION_DURATION}
      transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      hexpand
      halign={Gtk.Align.FILL}
      valign={Gtk.Align.FILL}
      vexpand
      child={content}
    />
  ) as Gtk.Widget
  const menuSlot = (
    <box
      class="widget-feed-hub-menu-slot"
      canTarget={isFeedHubMenuRevealed}
      widthRequest={FEED_HUB_MENU_WIDTH}
      halign={Gtk.Align.START}
      valign={Gtk.Align.FILL}
      vexpand
    >
      {revealer}
    </box>
  ) as Gtk.Widget
  const scrim = (
    <box
      class="widget-feed-hub-menu-scrim"
      canTarget={isFeedHubMenuRevealed}
      hexpand
      vexpand
      $={(self) => addPrimaryClick(self, closeActiveMenu)}
    />
  ) as Gtk.Widget
  const shell = (
    <box
      class="widget-feed-hub-menu-shell"
      orientation={Gtk.Orientation.HORIZONTAL}
      canTarget={isFeedHubMenuRevealed}
      hexpand
      vexpand
      $={(self) => {
        addOutsideClickCapture(self, closeActiveMenu)
        addCloseOnEscape(self, closeGlobalMenus, { grabFocus: true })
      }}
    >
      {menuSlot}
      {scrim}
    </box>
  ) as Gtk.Widget

  return (
    <window
      {...monitorProps}
      name="feed-hub-menu"
      class="widget-feed-hub-menu-window"
      visible={isFeedHubMenuVisible}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM
      }
      $={(self) => {
        const updateLayerMargins = () => {
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.TOP,
            barExclusiveZone.peek() + FEED_HUB_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.RIGHT,
            FEED_HUB_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.BOTTOM,
            FEED_HUB_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.LEFT,
            FEED_HUB_MENU_MARGIN,
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
      {shell}
    </window>
  )
}
