import { createState, type Accessor } from "ags"
import GLib from "gi://GLib?version=2.0"
import {
  createHwMonitorFetcher,
  type HwMonitorSnapshot,
} from "../../../utils/hw-monitor"

const HW_MONITOR_STATE_KEYS = ["cpu", "gpu", "ram"] as const

export type HwMonitorStateKey = (typeof HW_MONITOR_STATE_KEYS)[number]
export type HwMonitorPollingRate =
  | number
  | Partial<Record<HwMonitorStateKey, number>>

export type HwMonitorStoreProps = {
  pollingRate?: HwMonitorPollingRate
}

export type HwMonitorStore = {
  state: Accessor<HwMonitorSnapshot>
  refetch: () => void
  dispose: () => void
}

export const DEFAULT_HW_MONITOR_POLLING_RATE = 1000
const MIN_HW_MONITOR_POLLING_RATE = 100

type NormalizedPollingRates = Record<HwMonitorStateKey, number>

function normalizePollingRate(pollingRate: number | null | undefined) {
  if (!Number.isFinite(pollingRate)) {
    return DEFAULT_HW_MONITOR_POLLING_RATE
  }

  return Math.max(
    MIN_HW_MONITOR_POLLING_RATE,
    Math.round(pollingRate ?? DEFAULT_HW_MONITOR_POLLING_RATE),
  )
}

function normalizePollingRates(
  pollingRate: HwMonitorPollingRate | null | undefined,
): NormalizedPollingRates {
  if (typeof pollingRate === "number" || pollingRate == null) {
    const rate = normalizePollingRate(pollingRate)

    return {
      cpu: rate,
      gpu: rate,
      ram: rate,
    }
  }

  return {
    cpu: normalizePollingRate(pollingRate.cpu),
    gpu: normalizePollingRate(pollingRate.gpu),
    ram: normalizePollingRate(pollingRate.ram),
  }
}

function createInitialHwMonitorState(): HwMonitorSnapshot {
  return {
    fetchedAt: 0,
    cpu: {
      usagePercent: null,
      averageCoreClockMHz: null,
      averageTemperatureC: null,
      hottestTemperatureC: null,
    },
    gpu: {
      usagePercent: null,
      averageCoreClockMHz: null,
      temperatureC: null,
      vramTemperatureC: null,
      vramUsedBytes: null,
      vramTotalBytes: null,
      vramUsagePercent: null,
    },
    ram: {
      usedBytes: null,
      usagePercent: null,
    },
  }
}

export function createHwMonitorStore(
  props: HwMonitorStoreProps = {},
): HwMonitorStore {
  const pollingRates = normalizePollingRates(props.pollingRate)
  const fetcher = createHwMonitorFetcher()
  const [state, setState] = createState<HwMonitorSnapshot>(
    createInitialHwMonitorState(),
  )
  const idleIds: Record<HwMonitorStateKey, number> = {
    cpu: 0,
    gpu: 0,
    ram: 0,
  }
  const pollingIds: Record<HwMonitorStateKey, number> = {
    cpu: 0,
    gpu: 0,
    ram: 0,
  }
  let disposed = false

  function refetchSliceNow(key: HwMonitorStateKey) {
    try {
      const fetchedAt = Date.now()

      switch (key) {
        case "cpu":
          setState((current) => ({
            ...current,
            fetchedAt,
            cpu: fetcher.fetchCpu(),
          }))
          break
        case "gpu":
          setState((current) => ({
            ...current,
            fetchedAt,
            gpu: fetcher.fetchGpu(),
          }))
          break
        case "ram":
          setState((current) => ({
            ...current,
            fetchedAt,
            ram: fetcher.fetchRam(),
          }))
          break
      }
    } catch (error) {
      console.error(`Failed to fetch HW monitor ${key} state`, error)
    }
  }

  function queueRefetchSlice(key: HwMonitorStateKey) {
    if (disposed || idleIds[key] !== 0) {
      return
    }

    idleIds[key] = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      idleIds[key] = 0
      refetchSliceNow(key)
      return GLib.SOURCE_REMOVE
    })
  }

  function queueRefetch() {
    for (const key of HW_MONITOR_STATE_KEYS) {
      queueRefetchSlice(key)
    }
  }

  function dispose() {
    disposed = true

    for (const key of HW_MONITOR_STATE_KEYS) {
      if (idleIds[key] !== 0) {
        GLib.source_remove(idleIds[key])
        idleIds[key] = 0
      }

      if (pollingIds[key] !== 0) {
        GLib.source_remove(pollingIds[key])
        pollingIds[key] = 0
      }
    }
  }

  queueRefetch()
  for (const key of HW_MONITOR_STATE_KEYS) {
    pollingIds[key] = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      pollingRates[key],
      () => {
        queueRefetchSlice(key)
        return !disposed
      },
    )
  }

  return {
    state,
    refetch: queueRefetch,
    dispose,
  }
}
