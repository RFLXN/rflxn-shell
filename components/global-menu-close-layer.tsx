import { Astal, Gtk } from "ags/gtk4"
import type Gdk from "gi://Gdk?version=4.0"
import { closeActiveMenu, isAnyMenuRevealed } from "./global-store"

type GlobalMenuCloseLayerProps = {
  gdkmonitor: Gdk.Monitor
}

export default function GlobalMenuCloseLayer({
  gdkmonitor,
}: GlobalMenuCloseLayerProps) {
  const geometry = gdkmonitor.get_geometry()

  return (
    <window
      gdkmonitor={gdkmonitor}
      name={`global-menu-close-layer-${gdkmonitor.get_connector()}`}
      namespace={`global-menu-close-layer-${gdkmonitor.get_connector()}`}
      class="global-menu-close-layer"
      visible={isAnyMenuRevealed}
      canTarget={isAnyMenuRevealed}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM
      }
    >
      <button
        class="global-menu-close-scrim"
        canTarget={isAnyMenuRevealed}
        focusable={false}
        focusOnClick={false}
        hasFrame={false}
        hexpand
        vexpand
        widthRequest={geometry.width}
        heightRequest={geometry.height}
        halign={Gtk.Align.FILL}
        valign={Gtk.Align.FILL}
        $={(self) => {
          self.connect("clicked", closeActiveMenu)
        }}
      />
    </window>
  )
}
