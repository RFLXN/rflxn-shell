import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import AstalWp from "gi://AstalWp?version=0.1"

export type VolumeState = {
  hasDefaultSpeaker: boolean
  muted: boolean
  volume: number
  volumePercent: number
}

type VolumeStore = {
  state: Accessor<VolumeState>
  refetch: () => void
  dispose: () => void
}

const INITIAL_VOLUME_STATE: VolumeState = {
  hasDefaultSpeaker: false,
  muted: false,
  volume: 0,
  volumePercent: 0,
}

const WP_REFRESH_SIGNALS = [
  "ready",
  "notify::default-speaker",
] as const

const SPEAKER_REFRESH_SIGNALS = [
  "notify::volume",
  "notify::mute",
] as const

function sameVolumeState(prev: VolumeState, next: VolumeState) {
  return (
    prev.hasDefaultSpeaker === next.hasDefaultSpeaker &&
    prev.muted === next.muted &&
    prev.volume === next.volume &&
    prev.volumePercent === next.volumePercent
  )
}

function toVolumePercent(volume: number) {
  return Math.round(Math.max(0, volume) * 100)
}

function createVolumeStore(): VolumeStore {
  const wp = AstalWp.get_default()
  const [state, setState] = createState<VolumeState>(
    INITIAL_VOLUME_STATE,
    { equals: sameVolumeState },
  )
  const wpSignalIds = WP_REFRESH_SIGNALS.map((signal) =>
    wp.connect(signal, () => queueRefetch()),
  )
  let speakerSubscription:
    | { speaker: AstalWp.Endpoint; ids: number[] }
    | null = null
  let idleId = 0
  let disposed = false

  function getDefaultSpeaker() {
    try {
      return wp.get_default_speaker() ?? null
    } catch {
      return null
    }
  }

  function disconnectSpeakerSignals() {
    if (!speakerSubscription) {
      return
    }

    for (const id of speakerSubscription.ids) {
      speakerSubscription.speaker.disconnect(id)
    }

    speakerSubscription = null
  }

  function syncSpeakerSignals() {
    const speaker = getDefaultSpeaker()

    if (speakerSubscription?.speaker === speaker) {
      return
    }

    disconnectSpeakerSignals()

    if (!speaker) {
      return
    }

    speakerSubscription = {
      speaker,
      ids: SPEAKER_REFRESH_SIGNALS.map((signal) =>
        speaker.connect(signal, () => queueRefetch()),
      ),
    }
  }

  function readVolumeState(): VolumeState {
    const speaker = getDefaultSpeaker()

    if (!speaker) {
      return INITIAL_VOLUME_STATE
    }

    const volume = speaker.get_volume()

    return {
      hasDefaultSpeaker: true,
      muted: speaker.get_mute(),
      volume,
      volumePercent: toVolumePercent(volume),
    }
  }

  function refetchNow() {
    try {
      syncSpeakerSignals()
      setState(readVolumeState())
      syncSpeakerSignals()
    } catch (error) {
      console.error("Failed to fetch volume state", error)
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

    for (const id of wpSignalIds) {
      wp.disconnect(id)
    }

    disconnectSpeakerSignals()
  }

  queueRefetch()

  return {
    state,
    refetch: queueRefetch,
    dispose,
  }
}

export const volumeStore = createVolumeStore()
export const volumeState = volumeStore.state
export const hasDefaultSpeaker = volumeState.as(
  (state) => state.hasDefaultSpeaker,
)
export const isDefaultSpeakerMuted = volumeState.as((state) => state.muted)
export const defaultSpeakerVolume = volumeState.as((state) => state.volume)
export const defaultSpeakerVolumePercent = volumeState.as(
  (state) => state.volumePercent,
)
export const refetchVolume = volumeStore.refetch
export const disposeVolumeStore = volumeStore.dispose
