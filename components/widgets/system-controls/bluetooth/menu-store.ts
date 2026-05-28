import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalBluetooth from "gi://AstalBluetooth?version=0.1"

export type BluetoothMenuAdapter = {
  name: string
}

export type BluetoothMenuDevice = {
  name: string
  connected: boolean
  connecting: boolean
  paired: boolean
  trusted: boolean
  blocked: boolean
  batteryPercent: number | null
  rssi: number | null
}

export type BluetoothMenuState = {
  hasAdapter: boolean
  isPowered: boolean
  isConnected: boolean
  adapters: BluetoothMenuAdapter[]
  connectedDevices: BluetoothMenuDevice[]
}

type BluetoothMenuStore = {
  state: Accessor<BluetoothMenuState>
  refetch: () => void
  dispose: () => void
}

const BLUETOOTH_MENU_REFRESH_SIGNALS = [
  "adapter-added",
  "adapter-removed",
  "device-added",
  "device-removed",
  "notify::is-powered",
  "notify::is-connected",
  "notify::adapter",
  "notify::adapters",
  "notify::devices",
] as const
const ADAPTER_REFRESH_SIGNALS = [
  "notify::alias",
  "notify::name",
  "notify::address",
  "notify::powered",
] as const
const DEVICE_REFRESH_SIGNALS = [
  "notify::alias",
  "notify::name",
  "notify::address",
  "notify::connected",
  "notify::connecting",
  "notify::paired",
  "notify::trusted",
  "notify::blocked",
  "notify::battery-percentage",
  "notify::rssi",
] as const
const DEFAULT_BLUETOOTH_MENU_STATE: BluetoothMenuState = {
  hasAdapter: false,
  isPowered: false,
  isConnected: false,
  adapters: [],
  connectedDevices: [],
}

function readString(read: () => string) {
  try {
    return read() || ""
  } catch {
    return ""
  }
}

function readBoolean(read: () => boolean) {
  try {
    return read()
  } catch {
    return false
  }
}

function readNumber(read: () => number) {
  try {
    const value = read()

    return Number.isFinite(value) ? value : 0
  } catch {
    return 0
  }
}

function toBatteryPercent(value: number) {
  if (value < 0) return null

  const percent = value <= 1 ? value * 100 : value

  return Math.max(0, Math.min(100, Math.round(percent)))
}

function getAdapterName(adapter: AstalBluetooth.Adapter) {
  return readString(() => adapter.get_alias())
    || readString(() => adapter.get_name())
    || readString(() => adapter.get_address())
    || "Bluetooth adapter"
}

function getDeviceName(device: AstalBluetooth.Device) {
  return readString(() => device.get_alias())
    || readString(() => device.get_name())
    || readString(() => device.get_address())
    || "Unknown device"
}

function readAdapter(adapter: AstalBluetooth.Adapter): BluetoothMenuAdapter {
  return {
    name: getAdapterName(adapter),
  }
}

function readDevice(device: AstalBluetooth.Device): BluetoothMenuDevice {
  const batteryPercent = readNumber(() => device.get_battery_percentage())
  const rssi = readNumber(() => device.get_rssi())

  return {
    name: getDeviceName(device),
    connected: readBoolean(() => device.get_connected()),
    connecting: readBoolean(() => device.get_connecting()),
    paired: readBoolean(() => device.get_paired()),
    trusted: readBoolean(() => device.get_trusted()),
    blocked: readBoolean(() => device.get_blocked()),
    batteryPercent: toBatteryPercent(batteryPercent),
    rssi: rssi === 0 ? null : Math.round(rssi),
  }
}

function sortDevices(
  first: BluetoothMenuDevice,
  second: BluetoothMenuDevice,
) {
  if (first.connecting !== second.connecting) {
    return first.connecting ? -1 : 1
  }

  return first.name.localeCompare(second.name)
}

function createBluetoothMenuStore(): BluetoothMenuStore {
  const bluetooth = AstalBluetooth.get_default()
  const [state, setState] = createState<BluetoothMenuState>(
    DEFAULT_BLUETOOTH_MENU_STATE,
  )
  const bluetoothSignalIds = BLUETOOTH_MENU_REFRESH_SIGNALS.map((signal) =>
    bluetooth.connect(signal, () => queueRefetch()),
  )
  const adapterSignalIds = new Map<AstalBluetooth.Adapter, number[]>()
  const deviceSignalIds = new Map<AstalBluetooth.Device, number[]>()
  let adapters: AstalBluetooth.Adapter[] = []
  let devices: AstalBluetooth.Device[] = []
  let idleId = 0
  let disposed = false

  function getAdapters() {
    try {
      return bluetooth.get_adapters().filter(Boolean)
    } catch {
      return []
    }
  }

  function getDevices() {
    try {
      return bluetooth.get_devices().filter(Boolean)
    } catch {
      return []
    }
  }

  function syncAdapterSubscriptions() {
    const nextAdapters = getAdapters()

    for (const adapter of adapters) {
      if (nextAdapters.includes(adapter)) continue

      const ids = adapterSignalIds.get(adapter) || []

      for (const id of ids) {
        adapter.disconnect(id)
      }

      adapterSignalIds.delete(adapter)
    }

    for (const adapter of nextAdapters) {
      if (adapterSignalIds.has(adapter)) continue

      adapterSignalIds.set(
        adapter,
        ADAPTER_REFRESH_SIGNALS.map((signal) =>
          adapter.connect(signal, () => queueRefetch()),
        ),
      )
    }

    adapters = nextAdapters
  }

  function syncDeviceSubscriptions() {
    const nextDevices = getDevices()

    for (const device of devices) {
      if (nextDevices.includes(device)) continue

      const ids = deviceSignalIds.get(device) || []

      for (const id of ids) {
        device.disconnect(id)
      }

      deviceSignalIds.delete(device)
    }

    for (const device of nextDevices) {
      if (deviceSignalIds.has(device)) continue

      deviceSignalIds.set(
        device,
        DEVICE_REFRESH_SIGNALS.map((signal) =>
          device.connect(signal, () => queueRefetch()),
        ),
      )
    }

    devices = nextDevices
  }

  function readBluetoothMenuState(): BluetoothMenuState {
    const adapterState = adapters.map(readAdapter)
    const deviceState = devices.map(readDevice)
    const connectedDevices = deviceState
      .filter((device) => device.connected || device.connecting)
      .sort(sortDevices)
    const hasAdapter = adapterState.length > 0

    return {
      hasAdapter,
      isPowered: hasAdapter && readBoolean(() => bluetooth.get_is_powered()),
      isConnected:
        hasAdapter && readBoolean(() => bluetooth.get_is_connected()),
      adapters: adapterState,
      connectedDevices,
    }
  }

  function refetchNow() {
    try {
      syncAdapterSubscriptions()
      syncDeviceSubscriptions()
      setState(readBluetoothMenuState())
    } catch (error) {
      console.error("Failed to fetch bluetooth menu state", error)
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

    for (const id of bluetoothSignalIds) {
      bluetooth.disconnect(id)
    }

    for (const [adapter, ids] of adapterSignalIds) {
      for (const id of ids) {
        adapter.disconnect(id)
      }
    }

    for (const [device, ids] of deviceSignalIds) {
      for (const id of ids) {
        device.disconnect(id)
      }
    }

    adapterSignalIds.clear()
    deviceSignalIds.clear()
  }

  queueRefetch()

  return {
    state,
    refetch: queueRefetch,
    dispose,
  }
}

export const bluetoothMenuStore = createBluetoothMenuStore()
export const bluetoothMenuState = bluetoothMenuStore.state
export const refetchBluetoothMenu = bluetoothMenuStore.refetch
export const disposeBluetoothMenuStore = bluetoothMenuStore.dispose
