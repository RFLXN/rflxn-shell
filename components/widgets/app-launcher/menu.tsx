import { onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import type Gdk from "gi://Gdk?version=4.0"
import Gtk4LayerShell from "gi://Gtk4LayerShell?version=1.0"
import { Astal, Gtk } from "ags/gtk4"
import { barExclusiveZone } from "../../bar/store"
import {
  APP_LAUNCHER_TRANSITION_DURATION,
  closeAppLauncher,
  closeGlobalMenus,
  isAppLauncherRevealed,
  isAppLauncherVisible,
} from "../../global-store"
import { addCloseOnEscape } from "../../menu-escape"
import AppLauncher from "."

type AppLauncherMenuProps = {
  gdkmonitor?: Gdk.Monitor
}

const APP_LAUNCHER_MENU_MARGIN = 8
const APP_LAUNCHER_MENU_WIDTH = 640
const APP_LAUNCHER_MENU_HEIGHT = 560

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

export default function AppLauncherMenu({ gdkmonitor }: AppLauncherMenuProps) {
  const monitorProps = gdkmonitor ? { gdkmonitor } : {}
  const content = (
    <box
      class="widget-app-launcher-menu-content"
      orientation={Gtk.Orientation.VERTICAL}
      overflow={Gtk.Overflow.HIDDEN}
      widthRequest={APP_LAUNCHER_MENU_WIDTH}
      heightRequest={APP_LAUNCHER_MENU_HEIGHT}
    >
      <AppLauncher />
    </box>
  ) as Gtk.Widget
  const revealer = (
    <revealer
      class="widget-app-launcher-menu-revealer"
      revealChild={isAppLauncherRevealed}
      transitionDuration={APP_LAUNCHER_TRANSITION_DURATION}
      transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.END}
      child={content}
    />
  ) as Gtk.Widget
  const menuSlot = (
    <box
      class="widget-app-launcher-menu-slot"
      canTarget={isAppLauncherRevealed}
      widthRequest={APP_LAUNCHER_MENU_WIDTH}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.END}
    >
      {revealer}
    </box>
  ) as Gtk.Widget
  const scrim = (
    <box
      class="widget-app-launcher-menu-scrim"
      canTarget={isAppLauncherRevealed}
      hexpand
      vexpand
      $={(self) => addPrimaryClick(self, closeAppLauncher)}
    />
  ) as Gtk.Widget
  const shell = (
    <overlay
      class="widget-app-launcher-menu-shell"
      canTarget={isAppLauncherRevealed}
      hexpand
      vexpand
      child={scrim}
      $={(self) => {
        self.add_overlay(menuSlot)
        self.set_measure_overlay(menuSlot, false)
        addCloseOnEscape(self, closeGlobalMenus, { grabFocus: true })
      }}
    />
  ) as Gtk.Widget

  return (
    <window
      {...monitorProps}
      name="app-launcher-menu"
      namespace="app-launcher-menu"
      class="widget-app-launcher-menu-window"
      visible={isAppLauncherVisible}
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
            barExclusiveZone.peek() + APP_LAUNCHER_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.RIGHT,
            APP_LAUNCHER_MENU_MARGIN,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.BOTTOM,
            0,
          )
          Gtk4LayerShell.set_margin(
            self,
            Gtk4LayerShell.Edge.LEFT,
            APP_LAUNCHER_MENU_MARGIN,
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
