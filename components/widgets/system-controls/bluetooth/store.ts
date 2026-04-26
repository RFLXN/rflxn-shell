import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalBluetooth from "gi://AstalBluetooth?version=0.1"

type BluetoothState = {
  hasAdapter: boolean
  isPowered: boolean
  hasConnectedDevice: boolean
}

type BluetoothStore = {
  state: Accessor<BluetoothState>
  hasAdapter: Accessor<boolean>
  isPowered: Accessor<boolean>
  hasConnectedDevice: Accessor<boolean>
  refetch: () => void
  dispose: () => void
}

const BLUETOOTH_REFRESH_SIGNALS = [
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

function createBluetoothStore(): BluetoothStore {
  const bluetooth = AstalBluetooth.get_default()
  const [state, setState] = createState<BluetoothState>({
    hasAdapter: false,
    isPowered: false,
    hasConnectedDevice: false,
  })
  const [hasAdapter, setHasAdapter] = createState(false)
  const [isPowered, setIsPowered] = createState(false)
  const [hasConnectedDevice, setHasConnectedDevice] = createState(false)
  const bluetoothSignalIds = BLUETOOTH_REFRESH_SIGNALS.map((signal) =>
    bluetooth.connect(signal, () => queueRefetch()),
  )
  let idleId = 0
  let disposed = false

  function getAdapters() {
    try {
      return bluetooth.get_adapters().filter(Boolean)
    } catch {
      return []
    }
  }

  function refetchNow() {
    try {
      const hasAdapters = getAdapters().length > 0
      const nextState = {
        hasAdapter: hasAdapters,
        isPowered: hasAdapters && bluetooth.get_is_powered(),
        hasConnectedDevice: hasAdapters && bluetooth.get_is_connected(),
      }

      setState(nextState)
      setHasAdapter(nextState.hasAdapter)
      setIsPowered(nextState.isPowered)
      setHasConnectedDevice(nextState.hasConnectedDevice)
    } catch (error) {
      console.error("Failed to fetch bluetooth state", error)
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
  }

  queueRefetch()

  return {
    state,
    hasAdapter,
    isPowered,
    hasConnectedDevice,
    refetch: queueRefetch,
    dispose,
  }
}

export const bluetoothStore = createBluetoothStore()
export const bluetoothState = bluetoothStore.state
export const hasBluetoothAdapter = bluetoothStore.hasAdapter
export const isBluetoothPowered = bluetoothStore.isPowered
export const hasConnectedBluetoothDevice = bluetoothStore.hasConnectedDevice
export const bluetoothIconName = bluetoothState.as((state) => {
  if (state.hasConnectedDevice) {
    return "bluetooth_connected"
  }

  if (state.isPowered) {
    return "bluetooth"
  }

  return "bluetooth_disabled"
})
export const refetchBluetooth = bluetoothStore.refetch
export const disposeBluetoothStore = bluetoothStore.dispose
