import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"

export type HwMonitorCpuSnapshot = {
  usagePercent: number | null
  averageCoreClockMHz: number | null
  averageTemperatureC: number | null
  hottestTemperatureC: number | null
}

export type HwMonitorGpuSnapshot = {
  usagePercent: number | null
  averageCoreClockMHz: number | null
  temperatureC: number | null
  vramTemperatureC: number | null
  vramUsedBytes: number | null
  vramTotalBytes: number | null
  vramUsagePercent: number | null
}

export type HwMonitorRamSnapshot = {
  usedBytes: number | null
  usagePercent: number | null
}

export type HwMonitorSnapshot = {
  fetchedAt: number
  cpu: HwMonitorCpuSnapshot
  gpu: HwMonitorGpuSnapshot
  ram: HwMonitorRamSnapshot
}

export type HwMonitorFetcher = {
  fetchCpu: () => HwMonitorCpuSnapshot
  fetchGpu: () => HwMonitorGpuSnapshot
  fetchRam: () => HwMonitorRamSnapshot
  fetch: () => HwMonitorSnapshot
}

type CpuTimes = {
  idle: number
  total: number
}

type ResolvedCpuSensors = {
  temperatureInputPaths: string[]
  coreClockInputPaths: string[]
}

type ResolvedGpuSensors = {
  devicePath: string
  coreClockInputPath: string | null
  temperatureInputPath: string | null
  vramTemperatureInputPath: string | null
}

const decoder = new TextDecoder()

const PROC_STAT_PATH = "/proc/stat"
const PROC_MEMINFO_PATH = "/proc/meminfo"
const SYS_HWMON_ROOT = "/sys/class/hwmon"
const SYS_DRM_ROOT = "/sys/class/drm"
const SYS_CPUFREQ_ROOT = "/sys/devices/system/cpu/cpufreq"

const CPU_SENSOR_PRIORITIES = ["k10temp", "zenpower", "coretemp"] as const
const CPU_TEMP_LABEL_PRIORITIES = [
  "tctl",
  "package id 0",
  "tdie",
] as const
const GPU_TEMP_LABEL_PRIORITIES = ["junction", "edge"] as const
const VRAM_TEMP_LABEL_PRIORITIES = ["mem"] as const

function normalizeText(value: string | null | undefined) {
  return value?.trim().toLowerCase() ?? ""
}

function getCpuSensorPriority(name: string) {
  const index = CPU_SENSOR_PRIORITIES.indexOf(
    name as (typeof CPU_SENSOR_PRIORITIES)[number],
  )

  return index === -1 ? Number.MAX_SAFE_INTEGER : index
}

function roundToSingleDecimal(value: number) {
  return Math.round(value * 10) / 10
}

function toPercent(value: number, total: number) {
  if (!Number.isFinite(value) || !Number.isFinite(total) || total <= 0) {
    return null
  }

  return roundToSingleDecimal((value / total) * 100)
}

function readTextFile(path: string) {
  try {
    const [ok, contents] = GLib.file_get_contents(path)

    if (!ok) {
      return null
    }

    return decoder.decode(contents).trim()
  } catch {
    return null
  }
}

function readNumberFile(path: string) {
  const text = readTextFile(path)

  if (!text) {
    return null
  }

  const value = Number(text)

  return Number.isFinite(value) ? value : null
}

function readTemperatureC(path: string | null) {
  if (!path) {
    return null
  }

  const value = readNumberFile(path)

  if (value === null) {
    return null
  }

  return roundToSingleDecimal(value / 1000)
}

function listChildNames(path: string) {
  try {
    const directory = Gio.File.new_for_path(path)
    const enumerator = directory.enumerate_children(
      Gio.FILE_ATTRIBUTE_STANDARD_NAME,
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    const names: string[] = []

    try {
      let info: Gio.FileInfo | null = null

      while ((info = enumerator.next_file(null))) {
        const name = info.get_name()

        if (name) {
          names.push(name)
        }
      }
    } finally {
      enumerator.close(null)
    }

    return names.sort()
  } catch {
    return []
  }
}

function resolveTemperatureInputPath(
  basePath: string,
  preferredLabels: readonly string[],
) {
  const names = listChildNames(basePath)
  const labelEntries = new Map<string, string>()
  const inputNames = new Set<string>()

  for (const name of names) {
    const labelMatch = name.match(/^temp(\d+)_label$/)

    if (labelMatch) {
      const index = labelMatch[1]
      const label = normalizeText(readTextFile(`${basePath}/${name}`))

      if (label) {
        labelEntries.set(label, `${basePath}/temp${index}_input`)
      }

      continue
    }

    if (/^temp\d+_input$/.test(name)) {
      inputNames.add(name)
    }
  }

  for (const label of preferredLabels) {
    const inputPath = labelEntries.get(label)

    if (inputPath && inputNames.has(GLib.path_get_basename(inputPath))) {
      return inputPath
    }
  }

  const fallbackInput = [...inputNames].sort()[0]

  return fallbackInput ? `${basePath}/${fallbackInput}` : null
}

function listTemperatureInputPaths(basePath: string) {
  return listChildNames(basePath)
    .filter((name) => /^temp\d+_input$/.test(name))
    .map((name) => `${basePath}/${name}`)
}

function resolveCpuHwmonPath() {
  const hwmonPaths = listChildNames(SYS_HWMON_ROOT)
    .filter((name) => /^hwmon\d+$/.test(name))
    .map((name) => `${SYS_HWMON_ROOT}/${name}`)

  const candidates = hwmonPaths
    .map((path) => ({
      path,
      name: normalizeText(readTextFile(`${path}/name`)),
    }))
    .filter(({ name }) => getCpuSensorPriority(name) !== Number.MAX_SAFE_INTEGER)
    .sort((a, b) => getCpuSensorPriority(a.name) - getCpuSensorPriority(b.name))

  return candidates[0]?.path ?? null
}

function resolveCpuCoreClockInputPaths() {
  return listChildNames(SYS_CPUFREQ_ROOT)
    .filter((name) => /^policy\d+$/.test(name))
    .map((name) => `${SYS_CPUFREQ_ROOT}/${name}`)
    .map((policyPath) => {
      const names = listChildNames(policyPath)

      if (names.includes("scaling_cur_freq")) {
        return `${policyPath}/scaling_cur_freq`
      }

      if (names.includes("cpuinfo_cur_freq")) {
        return `${policyPath}/cpuinfo_cur_freq`
      }

      return null
    })
    .filter((path): path is string => path !== null)
}

function resolveCpuSensors() {
  const hwmonPath = resolveCpuHwmonPath()

  return {
    temperatureInputPaths: hwmonPath ? listTemperatureInputPaths(hwmonPath) : [],
    coreClockInputPaths: resolveCpuCoreClockInputPaths(),
  } satisfies ResolvedCpuSensors
}

function resolvePrimaryGpuDevicePath() {
  let bestDevicePath: string | null = null
  let bestVramTotal = -1
  let fallbackDevicePath: string | null = null

  for (const name of listChildNames(SYS_DRM_ROOT).filter((child) =>
    /^card\d+$/.test(child),
  )) {
    const devicePath = `${SYS_DRM_ROOT}/${name}/device`
    const vramTotal = readNumberFile(`${devicePath}/mem_info_vram_total`)

    if (vramTotal !== null && vramTotal > bestVramTotal) {
      bestDevicePath = devicePath
      bestVramTotal = vramTotal
    }

    if (
      fallbackDevicePath === null &&
      readNumberFile(`${devicePath}/gpu_busy_percent`) !== null
    ) {
      fallbackDevicePath = devicePath
    }
  }

  return bestDevicePath ?? fallbackDevicePath
}

function resolveGpuSensors() {
  const devicePath = resolvePrimaryGpuDevicePath()

  if (!devicePath) {
    return null
  }

  const hwmonName = listChildNames(`${devicePath}/hwmon`).find((name) =>
    /^hwmon\d+$/.test(name),
  )
  const hwmonPath = hwmonName ? `${devicePath}/hwmon/${hwmonName}` : null

  return {
    devicePath,
    coreClockInputPath:
      hwmonPath && listChildNames(hwmonPath).includes("freq1_input")
        ? `${hwmonPath}/freq1_input`
        : null,
    temperatureInputPath: hwmonPath
      ? resolveTemperatureInputPath(hwmonPath, GPU_TEMP_LABEL_PRIORITIES)
      : null,
    vramTemperatureInputPath: hwmonPath
      ? resolveTemperatureInputPath(hwmonPath, VRAM_TEMP_LABEL_PRIORITIES)
      : null,
  } satisfies ResolvedGpuSensors
}

function readCpuTimes() {
  const line = readTextFile(PROC_STAT_PATH)
    ?.split("\n")
    .find((candidate) => candidate.startsWith("cpu "))

  if (!line) {
    return null
  }

  const values = line
    .trim()
    .split(/\s+/)
    .slice(1)
    .map((value) => Number(value))

  if (values.length < 8 || values.some((value) => !Number.isFinite(value))) {
    return null
  }

  const [
    user = 0,
    nice = 0,
    system = 0,
    idle = 0,
    iowait = 0,
    irq = 0,
    softirq = 0,
    steal = 0,
  ] = values

  return {
    idle: idle + iowait,
    total: user + nice + system + idle + iowait + irq + softirq + steal,
  } satisfies CpuTimes
}

function readAverageValue(paths: string[], scale = 1) {
  const values = paths
    .map((path) => readNumberFile(path))
    .filter((value): value is number => value !== null)

  if (values.length === 0) {
    return null
  }

  const sum = values.reduce((acc, value) => acc + value, 0)

  return roundToSingleDecimal((sum / values.length) / scale)
}

function readTemperatureStats(paths: string[]) {
  const values = paths
    .map((path) => readTemperatureC(path))
    .filter((value): value is number => value !== null)

  if (values.length === 0) {
    return {
      averageTemperatureC: null,
      hottestTemperatureC: null,
    }
  }

  const sum = values.reduce((acc, value) => acc + value, 0)

  return {
    averageTemperatureC: roundToSingleDecimal(sum / values.length),
    hottestTemperatureC: Math.max(...values),
  }
}

function parseMeminfo() {
  const text = readTextFile(PROC_MEMINFO_PATH)

  if (!text) {
    return null
  }

  const entries = new Map<string, number>()

  for (const line of text.split("\n")) {
    const match = line.match(/^([A-Za-z_()]+):\s+(\d+)\s+kB$/)

    if (!match) {
      continue
    }

    entries.set(match[1], Number(match[2]))
  }

  return entries
}

function fetchGpuSnapshot(gpuSensors: ResolvedGpuSensors | null): HwMonitorGpuSnapshot {
  if (!gpuSensors) {
    return {
      usagePercent: null,
      averageCoreClockMHz: null,
      temperatureC: null,
      vramTemperatureC: null,
      vramUsedBytes: null,
      vramTotalBytes: null,
      vramUsagePercent: null,
    }
  }

  const usagePercent = readNumberFile(`${gpuSensors.devicePath}/gpu_busy_percent`)
  const vramUsedBytes = readNumberFile(`${gpuSensors.devicePath}/mem_info_vram_used`)
  const vramTotalBytes = readNumberFile(
    `${gpuSensors.devicePath}/mem_info_vram_total`,
  )

  return {
    usagePercent:
      usagePercent !== null ? roundToSingleDecimal(usagePercent) : null,
    averageCoreClockMHz: gpuSensors.coreClockInputPath
      ? readAverageValue([gpuSensors.coreClockInputPath], 1_000_000)
      : null,
    temperatureC: readTemperatureC(gpuSensors.temperatureInputPath),
    vramTemperatureC: readTemperatureC(gpuSensors.vramTemperatureInputPath),
    vramUsedBytes,
    vramTotalBytes,
    vramUsagePercent:
      vramUsedBytes !== null && vramTotalBytes !== null
        ? toPercent(vramUsedBytes, vramTotalBytes)
        : null,
  }
}

export function createHwMonitorFetcher(): HwMonitorFetcher {
  let previousCpuTimes: CpuTimes | null = null
  let cpuSensors: ResolvedCpuSensors | null = null
  let gpuSensors: ResolvedGpuSensors | null = null

  function getCpuSensors() {
    if (cpuSensors) {
      return cpuSensors
    }

    cpuSensors = resolveCpuSensors()
    return cpuSensors
  }

  function getGpuSensors() {
    if (gpuSensors) {
      return gpuSensors
    }

    gpuSensors = resolveGpuSensors()
    return gpuSensors
  }

  function fetchCpu() {
    const currentCpuTimes = readCpuTimes()
    let cpuUsagePercent: number | null = null

    // CPU usage needs two /proc/stat samples, so the first fetch only seeds state.
    if (currentCpuTimes && previousCpuTimes) {
      const totalDelta = currentCpuTimes.total - previousCpuTimes.total
      const idleDelta = currentCpuTimes.idle - previousCpuTimes.idle

      if (totalDelta > 0) {
        cpuUsagePercent = roundToSingleDecimal(
          ((totalDelta - idleDelta) / totalDelta) * 100,
        )
      }
    }

    if (currentCpuTimes) {
      previousCpuTimes = currentCpuTimes
    }

    const sensors = getCpuSensors()
    const temperatureStats = readTemperatureStats(sensors.temperatureInputPaths)

    return {
      usagePercent: cpuUsagePercent,
      averageCoreClockMHz: readAverageValue(sensors.coreClockInputPaths, 1000),
      averageTemperatureC: temperatureStats.averageTemperatureC,
      hottestTemperatureC: temperatureStats.hottestTemperatureC,
    } satisfies HwMonitorCpuSnapshot
  }

  function fetchGpu() {
    return fetchGpuSnapshot(getGpuSensors())
  }

  function fetchRam() {
    const meminfo = parseMeminfo()
    const totalKb = meminfo?.get("MemTotal") ?? null
    const availableKb = meminfo?.get("MemAvailable") ?? null
    const usedBytes =
      totalKb !== null && availableKb !== null
        ? (totalKb - availableKb) * 1024
        : null

    return {
      usedBytes,
      usagePercent:
        totalKb !== null && availableKb !== null
          ? toPercent(totalKb - availableKb, totalKb)
          : null,
    } satisfies HwMonitorRamSnapshot
  }

  function fetch() {
    return {
      fetchedAt: Date.now(),
      cpu: fetchCpu(),
      gpu: fetchGpu(),
      ram: fetchRam(),
    } satisfies HwMonitorSnapshot
  }

  return {
    fetchCpu,
    fetchGpu,
    fetchRam,
    fetch,
  }
}
