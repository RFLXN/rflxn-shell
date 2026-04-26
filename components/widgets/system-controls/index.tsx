import { Gtk } from "ags/gtk4"
import BatteryControl from "./battery"
import BluetoothControl from "./bluetooth"
import NetworkControl from "./network"
import VolumeControl from "./volume"
import {
  isSystemControlsMenuVisible,
  toggleSystemControlsMenu,
} from "./store"

function addPrimaryClick(widget: Gtk.Widget, onClick: () => void) {
  const click = Gtk.GestureClick.new()

  click.set_button(1)
  click.connect("released", (gesture, nPress) => {
    if (nPress !== 1) return

    gesture.set_state(Gtk.EventSequenceState.CLAIMED)
    onClick()
  })

  widget.add_controller(click)
  widget.set_cursor_from_name("pointer")
}

export default function SystemControlsWidget() {
  const content = (
    <box class="widget-system-controls-content" spacing={10}>
      <VolumeControl />
      <BatteryControl />
      <BluetoothControl />
      <NetworkControl />
    </box>
  ) as Gtk.Widget

  return (
    <centerbox
      class={isSystemControlsMenuVisible.as((visible) =>
        visible ? "widget-system-controls is-open" : "widget-system-controls",
      )}
      valign={Gtk.Align.CENTER}
      centerWidget={content}
      $={(self) => addPrimaryClick(self, toggleSystemControlsMenu)}
    />
  )
}
