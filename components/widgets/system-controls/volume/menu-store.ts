import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalWp from "gi://AstalWp?version=0.1"

export type VolumeMenuDevice = {
  id: number
  name: string
  description: string
  volume: number
  volumePercent: number
  muted: boolean
  isDefault: boolean
}

export type VolumeMenuState = {
  outputDevices: VolumeMenuDevice[]
  inputDevices: VolumeMenuDevice[]
}

export type VolumeMenuDeviceKind = "input" | "output"

type VolumeMenuStore = {
  state: Accessor<VolumeMenuState>
  refetch: () => void
  refetchAfterVolumeChange: () => void
  dispose: () => void
}

type AudioSubscription = {
  audio: AstalWp.Audio
  ids: number[]
}

type EndpointSubscription = {
  endpoint: AstalWp.Endpoint
  ids: number[]
}

const INITIAL_VOLUME_MENU_STATE: VolumeMenuState = {
  outputDevices: [],
  inputDevices: [],
}

const VOLUME_CHANGE_REFETCH_DELAY_MS = 250
let volumeChangeRefetchHoldUntilUs = 0

const WP_REFRESH_SIGNALS = [
  "ready",
  "device-added",
  "device-removed",
  "node-added",
  "node-removed",
  "notify::audio",
  "notify::default-speaker",
  "notify::default-microphone",
] as const

const AUDIO_REFRESH_SIGNALS = [
  "speaker-added",
  "speaker-removed",
  "microphone-added",
  "microphone-removed",
  "notify::speakers",
  "notify::microphones",
  "notify::default-speaker",
  "notify::default-microphone",
] as const

const ENDPOINT_REFRESH_SIGNALS = [
  "notify::volume",
  "notify::mute",
  "notify::is-default",
  "notify::name",
  "notify::description",
  "notify::id",
] as const

function sameVolumeMenuState(
  prev: VolumeMenuState,
  next: VolumeMenuState,
) {
  return JSON.stringify(prev) === JSON.stringify(next)
}

function normalizeText(value: string | null | undefined) {
  return value?.trim() ?? ""
}

function toVolumePercent(volume: number) {
  return Math.round(Math.max(0, volume) * 100)
}

function isVolumeMenuDevice(
  device: VolumeMenuDevice | null,
): device is VolumeMenuDevice {
  return device !== null
}

function sameEndpoint(
  endpoint: AstalWp.Endpoint,
  defaultEndpoint: AstalWp.Endpoint | null,
) {
  return defaultEndpoint !== null && endpoint.get_id() === defaultEndpoint.get_id()
}

function toVolumeMenuDevice(
  endpoint: AstalWp.Endpoint,
  defaultEndpoint: AstalWp.Endpoint | null,
): VolumeMenuDevice | null {
  try {
    const volume = endpoint.get_volume()

    return {
      id: endpoint.get_id(),
      name: normalizeText(endpoint.get_name()),
      description: normalizeText(endpoint.get_description()),
      volume,
      volumePercent: toVolumePercent(volume),
      muted: endpoint.get_mute(),
      isDefault: endpoint.get_is_default() || sameEndpoint(endpoint, defaultEndpoint),
    }
  } catch (error) {
    console.error("Failed to read WirePlumber endpoint", error)
    return null
  }
}

function createVolumeMenuStore(): VolumeMenuStore {
  const wp = AstalWp.get_default()
  const [state, setState] = createState<VolumeMenuState>(
    INITIAL_VOLUME_MENU_STATE,
    { equals: sameVolumeMenuState },
  )
  const wpSignalIds = WP_REFRESH_SIGNALS.map((signal) =>
    wp.connect(signal, () => queueRefetch()),
  )
  const endpointSubscriptions = new Map<string, EndpointSubscription>()
  let audioSubscription: AudioSubscription | null = null
  let idleId = 0
  let delayedRefetchId = 0
  let disposed = false

  function getAudio() {
    try {
      return wp.get_audio() ?? null
    } catch {
      return null
    }
  }

  function getDefaultSpeaker(audio: AstalWp.Audio | null) {
    if (!audio) return null

    try {
      return audio.get_default_speaker() ?? null
    } catch {
      return null
    }
  }

  function getDefaultMicrophone(audio: AstalWp.Audio | null) {
    if (!audio) return null

    try {
      return audio.get_default_microphone() ?? null
    } catch {
      return null
    }
  }

  function getSpeakers(audio: AstalWp.Audio | null) {
    if (!audio) return []

    try {
      return audio.get_speakers() ?? []
    } catch {
      return []
    }
  }

  function getMicrophones(audio: AstalWp.Audio | null) {
    if (!audio) return []

    try {
      return audio.get_microphones() ?? []
    } catch {
      return []
    }
  }

  function disconnectAudioSignals() {
    if (!audioSubscription) return

    for (const id of audioSubscription.ids) {
      audioSubscription.audio.disconnect(id)
    }

    audioSubscription = null
  }

  function syncAudioSignals() {
    const audio = getAudio()

    if (audioSubscription?.audio === audio) return

    disconnectAudioSignals()

    if (!audio) return

    audioSubscription = {
      audio,
      ids: AUDIO_REFRESH_SIGNALS.map((signal) =>
        audio.connect(signal, () => queueRefetch()),
      ),
    }
  }

  function disconnectEndpointSubscription(key: string) {
    const subscription = endpointSubscriptions.get(key)

    if (!subscription) return

    for (const id of subscription.ids) {
      subscription.endpoint.disconnect(id)
    }

    endpointSubscriptions.delete(key)
  }

  function endpointKey(kind: "input" | "output", endpoint: AstalWp.Endpoint) {
    return `${kind}:${endpoint.get_id()}`
  }

  function syncEndpointSignal(
    kind: "input" | "output",
    endpoint: AstalWp.Endpoint,
    activeKeys: Set<string>,
  ) {
    const key = endpointKey(kind, endpoint)
    const subscription = endpointSubscriptions.get(key)

    activeKeys.add(key)

    if (subscription?.endpoint === endpoint) return

    disconnectEndpointSubscription(key)

    endpointSubscriptions.set(key, {
      endpoint,
      ids: ENDPOINT_REFRESH_SIGNALS.map((signal) =>
        endpoint.connect(signal, () => queueEndpointRefetch(signal)),
      ),
    })
  }

  function syncEndpointSignals() {
    const audio = getAudio()
    const activeKeys = new Set<string>()

    for (const endpoint of getSpeakers(audio)) {
      syncEndpointSignal("output", endpoint, activeKeys)
    }

    for (const endpoint of getMicrophones(audio)) {
      syncEndpointSignal("input", endpoint, activeKeys)
    }

    for (const key of endpointSubscriptions.keys()) {
      if (!activeKeys.has(key)) {
        disconnectEndpointSubscription(key)
      }
    }
  }

  function readVolumeMenuState(): VolumeMenuState {
    const audio = getAudio()
    const defaultSpeaker = getDefaultSpeaker(audio)
    const defaultMicrophone = getDefaultMicrophone(audio)

    return {
      outputDevices: getSpeakers(audio)
        .map((endpoint) => toVolumeMenuDevice(endpoint, defaultSpeaker))
        .filter(isVolumeMenuDevice),
      inputDevices: getMicrophones(audio)
        .map((endpoint) => toVolumeMenuDevice(endpoint, defaultMicrophone))
        .filter(isVolumeMenuDevice),
    }
  }

  function refetchNow() {
    try {
      syncAudioSignals()
      syncEndpointSignals()
      setState(readVolumeMenuState())
      syncEndpointSignals()
    } catch (error) {
      console.error("Failed to fetch volume menu state", error)
    }
  }

  function queueRefetch() {
    if (disposed || idleId !== 0) return

    idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      idleId = 0
      refetchNow()
      return GLib.SOURCE_REMOVE
    })
  }

  function queueDelayedRefetch(delayMs: number) {
    if (disposed) return

    if (delayedRefetchId !== 0) {
      GLib.source_remove(delayedRefetchId)
      delayedRefetchId = 0
    }

    delayedRefetchId = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      delayMs,
      () => {
        delayedRefetchId = 0
        refetchNow()
        return GLib.SOURCE_REMOVE
      },
    )
  }

  function queueEndpointRefetch(
    signal: (typeof ENDPOINT_REFRESH_SIGNALS)[number],
  ) {
    if (signal !== "notify::volume") {
      queueRefetch()
      return
    }

    const remainingHoldMs = Math.ceil(
      (volumeChangeRefetchHoldUntilUs - GLib.get_monotonic_time()) / 1000,
    )

    if (remainingHoldMs > 0) {
      queueDelayedRefetch(remainingHoldMs)
      return
    }

    queueRefetch()
  }

  function refetchAfterVolumeChange() {
    volumeChangeRefetchHoldUntilUs =
      GLib.get_monotonic_time() + VOLUME_CHANGE_REFETCH_DELAY_MS * 1000
    queueDelayedRefetch(VOLUME_CHANGE_REFETCH_DELAY_MS)
  }

  function dispose() {
    disposed = true

    if (idleId !== 0) {
      GLib.source_remove(idleId)
      idleId = 0
    }

    if (delayedRefetchId !== 0) {
      GLib.source_remove(delayedRefetchId)
      delayedRefetchId = 0
    }

    for (const id of wpSignalIds) {
      wp.disconnect(id)
    }

    disconnectAudioSignals()

    for (const key of Array.from(endpointSubscriptions.keys())) {
      disconnectEndpointSubscription(key)
    }
  }

  queueRefetch()

  return {
    state,
    refetch: queueRefetch,
    refetchAfterVolumeChange,
    dispose,
  }
}

export const volumeMenuStore = createVolumeMenuStore()
export const volumeMenuState = volumeMenuStore.state
export const outputVolumeDevices = volumeMenuState.as(
  (state) => state.outputDevices,
)
export const inputVolumeDevices = volumeMenuState.as(
  (state) => state.inputDevices,
)
export const refetchVolumeMenu = volumeMenuStore.refetch
export const refetchVolumeMenuAfterVolumeChange =
  volumeMenuStore.refetchAfterVolumeChange
export const disposeVolumeMenuStore = volumeMenuStore.dispose

function clampMenuVolume(volume: number) {
  return Math.max(0, Math.min(volume, 1))
}

function getVolumeMenuEndpoint(kind: VolumeMenuDeviceKind, id: number) {
  const wp = AstalWp.get_default()
  const audio = wp.get_audio()

  if (kind === "output") {
    return audio.get_speaker(id)
  }

  return audio.get_microphone(id)
}

export function setVolumeMenuDeviceDefault(
  kind: VolumeMenuDeviceKind,
  id: number,
) {
  try {
    getVolumeMenuEndpoint(kind, id)?.set_is_default(true)
    refetchVolumeMenu()
  } catch (error) {
    console.error("Failed to set default volume device", error)
  }
}

export function setVolumeMenuDeviceMuted(
  kind: VolumeMenuDeviceKind,
  id: number,
  muted: boolean,
) {
  try {
    getVolumeMenuEndpoint(kind, id)?.set_mute(muted)
    refetchVolumeMenu()
  } catch (error) {
    console.error("Failed to set volume device mute state", error)
  }
}

export function setVolumeMenuDeviceVolume(
  kind: VolumeMenuDeviceKind,
  id: number,
  volume: number,
) {
  try {
    const endpoint = getVolumeMenuEndpoint(kind, id)

    if (!endpoint) return

    refetchVolumeMenuAfterVolumeChange()
    endpoint.set_volume(clampMenuVolume(volume))
  } catch (error) {
    console.error("Failed to set volume device level", error)
  }
}
