import GLib from "gi://GLib?version=2.0"
import type Gdk from "gi://Gdk?version=4.0"
import Gtk4LayerShell from "gi://Gtk4LayerShell?version=1.0"
import { Astal, Gtk } from "ags/gtk4"
import BarSkirt from "./BarSkirt"
import { setBarExclusiveZone } from "./store"

type BarWidgetElement = JSX.Element | JSX.Element[]

type BarWidgets = {
  left?: BarWidgetElement
  center?: BarWidgetElement
  right?: BarWidgetElement
}

type BarProps = {
  gdkmonitor?: Gdk.Monitor
  widgets?: BarWidgets
}

const BAR_BASE_HEIGHT = 46
const BAR_WIDGET_SPACING = 12

export default function Bar({ gdkmonitor, widgets }: BarProps) {
  const monitorProps = gdkmonitor ? { gdkmonitor } : {}
  const start = (
    <box
      class="bar-section bar-section-start"
      heightRequest={BAR_BASE_HEIGHT}
      overflow={Gtk.Overflow.HIDDEN}
      spacing={BAR_WIDGET_SPACING}
    >
      {widgets?.left}
    </box>
  ) as Gtk.Widget
  const center = (
    <box
      class="bar-section bar-section-center"
      heightRequest={BAR_BASE_HEIGHT}
      overflow={Gtk.Overflow.HIDDEN}
      spacing={BAR_WIDGET_SPACING}
    >
      {widgets?.center}
    </box>
  ) as Gtk.Widget
  const end = (
    <box
      class="bar-section bar-section-end"
      heightRequest={BAR_BASE_HEIGHT}
      overflow={Gtk.Overflow.HIDDEN}
      spacing={BAR_WIDGET_SPACING}
    >
      {widgets?.right}
    </box>
  ) as Gtk.Widget

  const railRow = (
    <box class="bar-rail-row">
      <box class="bar-rail" hexpand />
    </box>
  ) as Gtk.Widget

  const content = (
    <centerbox
      class="bar-content"
      heightRequest={BAR_BASE_HEIGHT}
      halign={Gtk.Align.FILL}
      valign={Gtk.Align.START}
      hexpand
      overflow={Gtk.Overflow.HIDDEN}
      startWidget={start}
      centerWidget={center}
      endWidget={end}
    />
  ) as Gtk.Widget

  const railLayer = (
    <overlay
      class="bar-rail-layer"
      heightRequest={BAR_BASE_HEIGHT}
      overflow={Gtk.Overflow.HIDDEN}
      child={railRow}
      $={(self) => {
        self.add_overlay(content)
        self.set_measure_overlay(content, false)
      }}
    />
  ) as Gtk.Widget

  const chrome = (
    <box class="bar-chrome" orientation={Gtk.Orientation.VERTICAL}>
      {railLayer}
      <box class="bar-skirt-row">
        <BarSkirt side="left" />
        <box class="bar-skirt-spacer" hexpand />
        <BarSkirt side="right" />
      </box>
    </box>
  ) as Gtk.Widget

  return (
    <window
      {...monitorProps}
      class="bar-window"
      visible
      layer={Astal.Layer.TOP}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      $={(self) => {
        const updateExclusiveZone = () => {
          const measuredRailHeight = railRow.measure(Gtk.Orientation.VERTICAL, -1)[1]
          const allocatedRailHeight = railRow.get_height()
          const exclusiveZone = allocatedRailHeight || measuredRailHeight

          if (exclusiveZone > 0) {
            Gtk4LayerShell.set_exclusive_zone(self, exclusiveZone)
            setBarExclusiveZone(exclusiveZone)
          }
        }

        const queueExclusiveZoneUpdate = () => {
          GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            updateExclusiveZone()
            return GLib.SOURCE_REMOVE
          })
        }

        queueExclusiveZoneUpdate()
        self.connect("map", queueExclusiveZoneUpdate)
        railRow.connect("map", queueExclusiveZoneUpdate)
        railRow.connect("notify::root", queueExclusiveZoneUpdate)
        railRow.connect("notify::css-classes", queueExclusiveZoneUpdate)
      }}
    >
      <box class="bar">{chrome}</box>
    </window>
  )
}
