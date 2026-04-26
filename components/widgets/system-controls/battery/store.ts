import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalBattery from "gi://AstalBattery?version=0.1"

type BatteryStore = {
  hasBattery: Accessor<boolean>
  refetch: () => void
  dispose: () => void
}

const UPOWER_REFRESH_SIGNALS = [
  "device-added",
  "device-removed",
  "notify::devices",
  "notify::display-device",
] as const

const BATTERY_DEVICE_REFRESH_SIGNALS = [
  "notify::device-type",
  "notify::power-supply",
  "notify::is-present",
] as const

function isSystemBatteryDevice(device: AstalBattery.Device) {
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

function createBatteryStore(): BatteryStore {
  const upower = AstalBattery.UPower.new()
  const [hasBattery, setHasBattery] = createState(false)
  const upowerSignalIds = UPOWER_REFRESH_SIGNALS.map((signal) =>
    upower.connect(signal, () => queueRefetch()),
  )
  const deviceSignalIds = new Map<AstalBattery.Device, number[]>()
  let idleId = 0
  let disposed = false

  function getDevices() {
    return upower.get_devices().filter(Boolean)
  }

  function syncDeviceSignals() {
    const activeDevices = new Set(getDevices())

    for (const device of activeDevices) {
      if (deviceSignalIds.has(device)) {
        continue
      }

      deviceSignalIds.set(
        device,
        BATTERY_DEVICE_REFRESH_SIGNALS.map((signal) =>
          device.connect(signal, () => queueRefetch()),
        ),
      )
    }

    for (const [device, ids] of deviceSignalIds) {
      if (activeDevices.has(device)) {
        continue
      }

      for (const id of ids) {
        device.disconnect(id)
      }

      deviceSignalIds.delete(device)
    }
  }

  function refetchNow() {
    try {
      syncDeviceSignals()
      setHasBattery(getDevices().some(isSystemBatteryDevice))
      syncDeviceSignals()
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

    for (const [device, ids] of deviceSignalIds) {
      for (const id of ids) {
        device.disconnect(id)
      }
    }

    deviceSignalIds.clear()
  }

  queueRefetch()

  return {
    hasBattery,
    refetch: queueRefetch,
    dispose,
  }
}

export const batteryStore = createBatteryStore()
export const hasBattery = batteryStore.hasBattery
export const refetchBattery = batteryStore.refetch
export const disposeBatteryStore = batteryStore.dispose
