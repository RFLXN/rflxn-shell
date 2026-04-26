import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalNetwork from "gi://AstalNetwork?version=0.1"

type NetworkTransport = "none" | "wired" | "wifi"
type NetworkInternet = "connected" | "disconnected"

type NetworkState = {
  transport: NetworkTransport
  internet: NetworkInternet
  hasAdapter: boolean
  hasWifiAccessPoint: boolean
  wifiStrengthLevel: 1 | 2 | 3 | 4
  iconName: string
  className: string
}

type NetworkStore = {
  state: Accessor<NetworkState>
  refetch: () => void
  dispose: () => void
}

const NETWORK_BASE_CLASS = "widget-system-controls-network"
const NETWORK_REFRESH_SIGNALS = [
  "notify::wifi",
  "notify::wired",
  "notify::primary",
  "notify::connectivity",
  "notify::state",
] as const
const WIFI_REFRESH_SIGNALS = [
  "access-point-added",
  "access-point-removed",
  "state-changed",
  "notify::active-access-point",
  "notify::access-points",
  "notify::enabled",
  "notify::internet",
  "notify::ssid",
  "notify::strength",
  "notify::state",
  "notify::icon-name",
] as const
const WIRED_REFRESH_SIGNALS = [
  "notify::internet",
  "notify::state",
  "notify::icon-name",
] as const

const DEFAULT_NETWORK_STATE: NetworkState = {
  transport: "none",
  internet: "disconnected",
  hasAdapter: false,
  hasWifiAccessPoint: false,
  wifiStrengthLevel: 1,
  iconName: "conversion_path_off",
  className: `${NETWORK_BASE_CLASS} is-offline`,
}

function toWifiStrengthLevel(strength: number): 1 | 2 | 3 | 4 {
  if (strength >= 75) return 4
  if (strength >= 50) return 3
  if (strength >= 25) return 2

  return 1
}

function toWifiIconName(strengthLevel: 1 | 2 | 3 | 4) {
  if (strengthLevel === 4) {
    return "signal_wifi_4_bar"
  }

  return `network_wifi_${strengthLevel}_bar`
}

function isWifiAccessPointConnected(wifi: AstalNetwork.Wifi) {
  try {
    return wifi.get_enabled()
      && wifi.get_state() === AstalNetwork.DeviceState.ACTIVATED
  } catch {
    return false
  }
}

function createNetworkStore(): NetworkStore {
  const network = AstalNetwork.get_default()
  const [state, setState] = createState<NetworkState>(DEFAULT_NETWORK_STATE)
  const networkSignalIds = NETWORK_REFRESH_SIGNALS.map((signal) =>
    network.connect(signal, () => queueRefetch()),
  )
  let wifi: AstalNetwork.Wifi | null = null
  let wired: AstalNetwork.Wired | null = null
  let wifiSignalIds: number[] = []
  let wiredSignalIds: number[] = []
  let idleId = 0
  let disposed = false

  function getWifi() {
    try {
      return network.get_wifi()
    } catch {
      return null
    }
  }

  function getWired() {
    try {
      return network.get_wired()
    } catch {
      return null
    }
  }

  function syncDeviceSubscriptions() {
    const nextWifi = getWifi()
    const nextWired = getWired()

    if (nextWifi !== wifi) {
      for (const id of wifiSignalIds) {
        wifi?.disconnect(id)
      }

      wifi = nextWifi
      wifiSignalIds = wifi
        ? WIFI_REFRESH_SIGNALS.map((signal) =>
            wifi!.connect(signal, () => queueRefetch()),
          )
        : []
    }

    if (nextWired !== wired) {
      for (const id of wiredSignalIds) {
        wired?.disconnect(id)
      }

      wired = nextWired
      wiredSignalIds = wired
        ? WIRED_REFRESH_SIGNALS.map((signal) =>
            wired!.connect(signal, () => queueRefetch()),
          )
        : []
    }
  }

  function readNetworkState(): NetworkState {
    const currentWifi = getWifi()
    const currentWired = getWired()
    const hasAdapter = Boolean(currentWifi || currentWired)
    const primary = network.get_primary()

    if (!hasAdapter) {
      return DEFAULT_NETWORK_STATE
    }

    if (primary === AstalNetwork.Primary.WIRED) {
      const hasInternet =
        currentWired?.get_internet() === AstalNetwork.Internet.CONNECTED

      return {
        transport: "wired",
        internet: hasInternet ? "connected" : "disconnected",
        hasAdapter,
        hasWifiAccessPoint: false,
        wifiStrengthLevel: 1,
        iconName: hasInternet ? "conversion_path" : "conversion_path_off",
        className: hasInternet
          ? NETWORK_BASE_CLASS
          : `${NETWORK_BASE_CLASS} is-offline`,
      }
    }

    if (
      !currentWifi
      || (
        primary !== AstalNetwork.Primary.WIFI
        && !isWifiAccessPointConnected(currentWifi)
      )
    ) {
      return DEFAULT_NETWORK_STATE
    }

    if (!isWifiAccessPointConnected(currentWifi)) {
      return {
        transport: "wifi",
        internet: "disconnected",
        hasAdapter,
        hasWifiAccessPoint: false,
        wifiStrengthLevel: 1,
        iconName: "signal_wifi_off",
        className: `${NETWORK_BASE_CLASS} is-offline`,
      }
    }

    const wifiStrengthLevel = toWifiStrengthLevel(currentWifi.get_strength())
    const hasInternet =
      currentWifi.get_internet() === AstalNetwork.Internet.CONNECTED

    return {
      transport: "wifi",
      internet: hasInternet ? "connected" : "disconnected",
      hasAdapter,
      hasWifiAccessPoint: true,
      wifiStrengthLevel,
      iconName: toWifiIconName(wifiStrengthLevel),
      className: hasInternet
        ? NETWORK_BASE_CLASS
        : `${NETWORK_BASE_CLASS} is-no-internet`,
    }
  }

  function refetchNow() {
    try {
      syncDeviceSubscriptions()
      setState(readNetworkState())
    } catch (error) {
      console.error("Failed to fetch network state", error)
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

    for (const id of networkSignalIds) {
      network.disconnect(id)
    }

    for (const id of wifiSignalIds) {
      wifi?.disconnect(id)
    }

    for (const id of wiredSignalIds) {
      wired?.disconnect(id)
    }
  }

  queueRefetch()

  return {
    state,
    refetch: queueRefetch,
    dispose,
  }
}

export const networkStore = createNetworkStore()
export const networkState = networkStore.state
export const networkIconName = networkState.as((state) => state.iconName)
export const networkClassName = networkState.as((state) => state.className)
export const refetchNetwork = networkStore.refetch
export const disposeNetworkStore = networkStore.dispose
