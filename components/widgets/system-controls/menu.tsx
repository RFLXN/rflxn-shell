import { onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import type Gdk from "gi://Gdk?version=4.0"
import Gtk4LayerShell from "gi://Gtk4LayerShell?version=1.0"
import { Astal, Gtk } from "ags/gtk4"
import { barExclusiveZone } from "../../bar/store"
import {
  closeActiveMenu,
  closeGlobalMenus,
  openShutdownConfirmation,
} from "../../global-store"
import Icon from "../../icon"
import { addCloseOnEscape } from "../../menu-escape"
import type { ShutdownConfirmationAction } from "../../shutdown-confirmation-overlay"
import {
  SYSTEM_CONTROLS_MENU_TRANSITION_DURATION,
  isSystemControlsMenuRevealed,
  isSystemControlsMenuVisible,
} from "./store"
import BluetoothMenu from "./bluetooth/menu"
import VolumeMenu from "./volume/menu"

type SystemControlsMenuProps = {
  gdkmonitor?: Gdk.Monitor
}

const SYSTEM_CONTROLS_MENU_MARGIN = 6
const SYSTEM_CONTROLS_MENU_WIDTH = 450
const SYSTEM_CONTROLS_FOOTER_ACTIONS = [
  {
    action: "logout",
    icon: "logout",
    label: "Logout",
    className: "is-logout",
  },
  {
    action: "restart",
    icon: "restart_alt",
    label: "Restart",
    className: "is-restart",
  },
  {
    action: "shutdown",
    icon: "power_settings_new",
    label: "Power Off",
    className: "is-power",
  },
] as const

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
    const menuStart = widget.get_width() - SYSTEM_CONTROLS_MENU_WIDTH

    if (nPress !== 1 || x > menuStart) return

    gesture.set_state(Gtk.EventSequenceState.CLAIMED)
    onClick()
  })

  widget.add_controller(click)
}

function SystemControlsFooterButton({
  action,
  icon,
  label,
  className,
}: (typeof SYSTEM_CONTROLS_FOOTER_ACTIONS)[number] & {
  action: ShutdownConfirmationAction
}) {
  return (
    <button
      class={`widget-system-controls-menu-footer-button ${className}`}
      hexpand
      hasFrame={false}
      focusOnClick={false}
      child={(
        <box
          class="widget-system-controls-menu-footer-button-content"
          orientation={Gtk.Orientation.HORIZONTAL}
          spacing={6}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
        >
          <Icon
            name={icon}
            class="widget-system-controls-menu-footer-button-icon"
            size={16}
          />
          <label
            class="widget-system-controls-menu-footer-button-label text"
            label={label}
          />
        </box>
      ) as Gtk.Widget}
      $={(self) => {
        self.connect("clicked", () => {
          openShutdownConfirmation(action)
        })
      }}
    />
  )
}

export default function SystemControlsMenu({
  gdkmonitor,
}: SystemControlsMenuProps) {
  const monitorProps = gdkmonitor ? { gdkmonitor } : {}
  const scrollContent = (
    <box
      class="widget-system-controls-menu-scroll-content"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      vexpand
    >
      <VolumeMenu />
      <BluetoothMenu />
    </box>
  ) as Gtk.Widget
  const scrollArea = (
    <scrolledwindow
      class="widget-system-controls-menu-scroll"
      propagateNaturalWidth={false}
      propagateNaturalHeight={false}
      vexpand
      child={scrollContent}
      $={(self) => {
        self.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.set_overlay_scrolling(true)
      }}
    />
  ) as Gtk.Widget
  const footer = (
    <box
      class="widget-system-controls-menu-footer"
      orientation={Gtk.Orientation.HORIZONTAL}
      spacing={6}
      hexpand
    >
      {SYSTEM_CONTROLS_FOOTER_ACTIONS.map((action) => (
        <SystemControlsFooterButton {...action} />
      ))}
    </box>
  ) as Gtk.Widget
  const content = (
    <box
      class="widget-system-controls-menu-content"
      canTarget={isSystemControlsMenuRevealed}
      orientation={Gtk.Orientation.VERTICAL}
      widthRequest={SYSTEM_CONTROLS_MENU_WIDTH}
      halign={Gtk.Align.END}
      vexpand
    >
      {scrollArea}
      {footer}
    </box>
  ) as Gtk.Widget
  const revealer = (
    <revealer
      class="widget-system-controls-menu-revealer"
      revealChild={isSystemControlsMenuRevealed}
      transitionDuration={SYSTEM_CONTROLS_MENU_TRANSITION_DURATION}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      hexpand
      halign={Gtk.Align.FILL}
      valign={Gtk.Align.FILL}
      vexpand
      child={content}
    />
  ) as Gtk.Widget
  const menuSlot = (
    <box
      class="widget-system-controls-menu-slot"
      canTarget={isSystemControlsMenuRevealed}
      widthRequest={SYSTEM_CONTROLS_MENU_WIDTH}
      halign={Gtk.Align.END}
      valign={Gtk.Align.FILL}
      vexpand
    >
      {revealer}
    </box>
  ) as Gtk.Widget
  const scrim = (
    <box
      class="widget-system-controls-menu-scrim"
      canTarget={isSystemControlsMenuRevealed}
      hexpand
      vexpand
      $={(self) => addPrimaryClick(self, closeActiveMenu)}
    />
  ) as Gtk.Widget
  const shell = (
    <box
      class="widget-system-controls-menu-shell"
      orientation={Gtk.Orientation.HORIZONTAL}
      canTarget={isSystemControlsMenuRevealed}
      hexpand
      vexpand
      $={(self) => {
        addOutsideClickCapture(self, closeActiveMenu)
        addCloseOnEscape(self, closeGlobalMenus, { grabFocus: true })
      }}
    >
      {scrim}
      {menuSlot}
    </box>
  ) as Gtk.Widget

  return (
    <window
      {...monitorProps}
      name="system-controls-menu"
      class="widget-system-controls-menu-window"
      visible={isSystemControlsMenuVisible}
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
            barExclusiveZone.peek() + SYSTEM_CONTROLS_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.RIGHT,
            SYSTEM_CONTROLS_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.BOTTOM,
            SYSTEM_CONTROLS_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.LEFT,
            SYSTEM_CONTROLS_MENU_MARGIN,
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
