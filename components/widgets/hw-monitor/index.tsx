import { onCleanup, type Accessor } from "ags"
import { Gtk } from "ags/gtk4"
import {
  createHwMonitorStore,
  type HwMonitorPollingRate,
} from "./store"

type HwMonitorWidgetProps = {
  pollingRate?: HwMonitorPollingRate
}

const HW_MONITOR_CATEGORY_WIDTH = 31
const HW_MONITOR_VALUE_WIDTH = 48

type MetricStackProps = {
  top: string | Accessor<string>
  bottom: string | Accessor<string>
}

type FixedColumnProps = {
  width: number
  children?: JSX.Element | JSX.Element[]
}

function FixedColumn({ width, children }: FixedColumnProps) {
  return (
    <box
      widthRequest={width}
      halign={Gtk.Align.FILL}
      valign={Gtk.Align.CENTER}
    >
      {children}
    </box>
  )
}

function MetricStack({ top, bottom }: MetricStackProps) {
  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      halign={Gtk.Align.FILL}
      valign={Gtk.Align.CENTER}
    >
      <label class="text" label={top} xalign={0} />
      <label class="text" label={bottom} xalign={0} />
    </box>
  )
}

function formatPercent(value: number | null) {
  return value === null ? "--" : `${value.toFixed(1)}%`
}

function formatTemperature(value: number | null) {
  return value === null ? "--" : `${value.toFixed(1)}°C`
}

function formatClockGHz(value: number | null) {
  return value === null ? "--" : `${(value / 1000).toFixed(1)}GHz`
}

function formatMemoryGB(value: number | null) {
  return value === null ? "--" : `${(value / 1024 ** 3).toFixed(1)}GB`
}

export default function HwMonitorWidget({
  pollingRate = {
    cpu: 1000,
    gpu: 1000,
    ram: 1000,
  },
}: HwMonitorWidgetProps) {
  const store = createHwMonitorStore({ pollingRate })

  onCleanup(() => {
    store.dispose()
  })

  return (
    <box class="widget-hw-monitor" spacing={4} valign={Gtk.Align.CENTER}>
      <box spacing={2} valign={Gtk.Align.CENTER}>
        <FixedColumn width={HW_MONITOR_CATEGORY_WIDTH}>
          <label class="text" label="CPU" xalign={0} />
        </FixedColumn>
        <FixedColumn width={HW_MONITOR_VALUE_WIDTH}>
          <MetricStack
            top={store.state.as((state) =>
              formatClockGHz(state.cpu.averageCoreClockMHz),
            )}
            bottom={store.state.as((state) =>
              formatPercent(state.cpu.usagePercent),
            )}
          />
        </FixedColumn>
        <FixedColumn width={HW_MONITOR_VALUE_WIDTH}>
          <MetricStack
            top={store.state.as((state) =>
              formatTemperature(state.cpu.hottestTemperatureC),
            )}
            bottom={store.state.as((state) =>
              formatTemperature(state.cpu.averageTemperatureC),
            )}
          />
        </FixedColumn>
      </box>
      <box spacing={2} valign={Gtk.Align.CENTER}>
        <FixedColumn width={HW_MONITOR_CATEGORY_WIDTH}>
          <label class="text" label="GPU" xalign={0} />
        </FixedColumn>
        <FixedColumn width={HW_MONITOR_VALUE_WIDTH}>
          <MetricStack
            top={store.state.as((state) =>
              formatClockGHz(state.gpu.averageCoreClockMHz),
            )}
            bottom={store.state.as((state) =>
              formatPercent(state.gpu.usagePercent),
            )}
          />
        </FixedColumn>
        <FixedColumn width={HW_MONITOR_VALUE_WIDTH}>
          <MetricStack
            top={store.state.as((state) =>
              formatTemperature(state.gpu.temperatureC),
            )}
            bottom={store.state.as((state) =>
              formatTemperature(state.gpu.vramTemperatureC),
            )}
          />
        </FixedColumn>
      </box>
      <box spacing={2} valign={Gtk.Align.CENTER}>
        <FixedColumn width={HW_MONITOR_CATEGORY_WIDTH}>
          <label class="text" label="RAM" xalign={0} />
        </FixedColumn>
        <FixedColumn width={HW_MONITOR_VALUE_WIDTH}>
          <MetricStack
            top={store.state.as((state) => formatMemoryGB(state.ram.usedBytes))}
            bottom={store.state.as((state) => formatPercent(state.ram.usagePercent))}
          />
        </FixedColumn>
      </box>
    </box>
  )
}
