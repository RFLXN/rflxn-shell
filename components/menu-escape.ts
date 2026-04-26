import GLib from "gi://GLib?version=2.0"
import Gdk from "gi://Gdk?version=4.0"
import { Gtk } from "ags/gtk4"

type AddCloseOnEscapeOptions = {
  grabFocus?: boolean
}

function queueFocus(widget: Gtk.Widget) {
  GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
    widget.grab_focus()
    return GLib.SOURCE_REMOVE
  })
}

export function addCloseOnEscape(
  widget: Gtk.Widget,
  onClose: () => void,
  { grabFocus = false }: AddCloseOnEscapeOptions = {},
) {
  const keyController = Gtk.EventControllerKey.new()

  keyController.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
  keyController.connect("key-pressed", (_controller, keyval) => {
    if (keyval !== Gdk.KEY_Escape) return false

    onClose()
    return true
  })

  widget.add_controller(keyController)

  if (!grabFocus) return

  widget.set_focusable(true)
  widget.connect("map", () => queueFocus(widget))
}
