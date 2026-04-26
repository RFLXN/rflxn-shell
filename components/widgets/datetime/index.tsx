
import GLib from "gi://GLib?version=2.0"
import { Gtk } from "ags/gtk4"
import { createPoll } from "ags/time"

type DateTimeWidgetProps = {
  format?: string
}

export default function DateTimeWidget({
  format = "%Y-%m-%d %I:%M:%S %p",
}: DateTimeWidgetProps) {
  const datetime = createPoll("", 1000, () => {
    return GLib.DateTime.new_now_local().format(format) ?? ""
  })

  const label = (
    <label
      class="widget-datetime-text text"
      label={datetime}
      xalign={0.5}
    />
  ) as Gtk.Widget

  return (
    <centerbox
      class="widget-datetime"
      valign={Gtk.Align.CENTER}
      centerWidget={label}
    />
  )
}
