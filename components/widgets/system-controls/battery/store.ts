import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalBattery from "gi://AstalBattery?version=0.1"

type BatteryState = {
  hasBattery: boolean
  percentage: number
  charging: boolean
}

type BatteryStore = {
  state: Accessor<BatteryState>
  hasBattery: Accessor<boolean>
  percentage: Accessor<number>
  charging: Accessor<boolean>
  className: Accessor<string>
  refetch: () => void
  dispose: () => void
}

const INITIAL_BATTERY_STATE: BatteryState = {
  hasBattery: false,
  percentage: 0,
  charging: false,
}

const UPOWER_REFRESH_SIGNALS = [
  "device-added",
  "device-removed",
  "notify::devices",
  "notify::display-device",
] as const

const DISPLAY_DEVICE_REFRESH_SIGNALS = [
  "notify::device-type",
  "notify::power-supply",
  "notify::is-present",
  "notify::percentage",
  "notify::charging",
  "notify::state",
] as const

function sameBatteryState(prev: BatteryState, next: BatteryState) {
  return (
    prev.hasBattery === next.hasBattery &&
    prev.percentage === next.percentage &&
    prev.charging === next.charging
  )
}

function isSystemBatteryDevice(
  device: AstalBattery.Device | null,
): device is AstalBattery.Device {
  if (!device) {
    return false
  }

  try {
    return (
      device.get_device_type() === AstalBattery.Type.BATTERY &&
      device.get_power_supply() &&
      device.get_is_present()
    )
  } catch {
    return false
  }
}

function normalizeBatteryPercentage(value: number) {
  if (!Number.isFinite(value) || value <= 0) {
    return 0
  }

  return value <= 1 ? value * 100 : value
}

function createBatteryStore(): BatteryStore {
  const upower = AstalBattery.UPower.new()
  const [state, setState] = createState<BatteryState>(
    INITIAL_BATTERY_STATE,
    { equals: sameBatteryState },
  )
  const upowerSignalIds = UPOWER_REFRESH_SIGNALS.map((signal) =>
    upower.connect(signal, () => queueRefetch()),
  )
  let displayDeviceSubscription:
    | { device: AstalBattery.Device; ids: number[] }
    | null = null
  let idleId = 0
  let disposed = false

  function getDisplayDevice() {
    try {
      return upower.get_display_device() ?? null
    } catch {
      return null
    }
  }

  function disconnectDisplayDeviceSignals() {
    if (!displayDeviceSubscription) {
      return
    }

    for (const id of displayDeviceSubscription.ids) {
      displayDeviceSubscription.device.disconnect(id)
    }

    displayDeviceSubscription = null
  }

  function syncDisplayDeviceSignals() {
    const displayDevice = getDisplayDevice()

    if (displayDeviceSubscription?.device === displayDevice) {
      return
    }

    disconnectDisplayDeviceSignals()

    if (!displayDevice) {
      return
    }

    displayDeviceSubscription = {
      device: displayDevice,
      ids: DISPLAY_DEVICE_REFRESH_SIGNALS.map((signal) =>
        displayDevice.connect(signal, () => queueRefetch()),
      ),
    }
  }

  function readBatteryState(): BatteryState {
    const displayDevice = getDisplayDevice()

    if (!isSystemBatteryDevice(displayDevice)) {
      return INITIAL_BATTERY_STATE
    }

    return {
      hasBattery: true,
      percentage: normalizeBatteryPercentage(displayDevice.get_percentage()),
      charging: displayDevice.get_charging(),
    }
  }

  function refetchNow() {
    try {
      syncDisplayDeviceSignals()
      setState(readBatteryState())
      syncDisplayDeviceSignals()
    } catch (error) {
      console.error("Failed to fetch battery state", error)
    }
  }

  function queueRefetch() {
    if (disposed || idleId !== 0) {
      return
    }

    idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      idleId = 0
      refetchNow()
      return GLib.SOURCE_REMOVE
    })
  }

  function dispose() {
    disposed = true

    if (idleId !== 0) {
      GLib.source_remove(idleId)
      idleId = 0
    }

    for (const id of upowerSignalIds) {
      upower.disconnect(id)
    }

    disconnectDisplayDeviceSignals()
  }

  queueRefetch()

  return {
    state,
    hasBattery: state.as((currentState) => currentState.hasBattery),
    percentage: state.as((currentState) => currentState.percentage),
    charging: state.as((currentState) => currentState.charging),
    className: state.as((currentState) =>
      currentState.charging
        ? "widget-system-controls-battery is-charging"
        : "widget-system-controls-battery"
    ),
    refetch: queueRefetch,
    dispose,
  }
}

export const batteryStore = createBatteryStore()
export const batteryState = batteryStore.state
export const hasBattery = batteryStore.hasBattery
export const batteryPercentage = batteryStore.percentage
export const isBatteryCharging = batteryStore.charging
export const batteryClassName = batteryStore.className
export const refetchBattery = batteryStore.refetch
export const disposeBatteryStore = batteryStore.dispose
