import GLib from "gi://GLib?version=2.0"
import type AstalHyprland from "gi://AstalHyprland?version=0.1"

type XWaylandWindowSnapshot = {
  xid: string
  pid: number | null
  title: string
  className: string
  urgent: boolean
}

type ClientSnapshot = {
  address: string
  pid: number
  title: string
  initialTitle: string
  className: string
  initialClassName: string
  xwayland: boolean
  mapped: boolean
}

const decoder = new TextDecoder()
const FALLBACK_XPROP_PATHS = [
  "/run/current-system/sw/bin/xprop",
  "/usr/bin/xprop",
]

function findXprop() {
  const pathProgram = GLib.find_program_in_path("xprop")

  if (pathProgram) return pathProgram

  return (
    FALLBACK_XPROP_PATHS.find((path) =>
      GLib.file_test(path, GLib.FileTest.IS_EXECUTABLE),
    ) ?? null
  )
}

function spawnText(argv: string[]) {
  const [spawned, stdout, , waitStatus] = GLib.spawn_sync(
    null,
    argv,
    null,
    GLib.SpawnFlags.STDIN_FROM_DEV_NULL,
    null,
  )

  if (!spawned || !stdout) return null

  try {
    GLib.spawn_check_wait_status(waitStatus)
  } catch {
    return null
  }

  return decoder.decode(stdout).trim()
}

function normalize(value: string | null | undefined) {
  return value?.trim().toLowerCase() ?? ""
}

function parseXids(rootXpropOutput: string) {
  return rootXpropOutput.match(/0x[0-9a-fA-F]+/g) ?? []
}

function getPropertyValue(output: string, property: string) {
  const prefix = `${property}(`
  const line = output.split("\n").find((candidate) =>
    candidate.startsWith(prefix),
  )

  if (!line) return null

  const valueStart = line.indexOf("=")

  return valueStart === -1 ? null : line.slice(valueStart + 1).trim()
}

function parseQuotedStrings(value: string | null) {
  if (!value) return []

  const results: string[] = []
  const quotedString = /"((?:[^"\\]|\\.)*)"/g
  let match: RegExpExecArray | null = null

  while ((match = quotedString.exec(value))) {
    results.push(match[1].replace(/\\(.)/g, "$1"))
  }

  return results
}

function parsePid(output: string) {
  const value = getPropertyValue(output, "_NET_WM_PID")

  if (!value) return null

  const pid = Number(value)

  return Number.isFinite(pid) && pid > 0 ? pid : null
}

function parseTitle(output: string) {
  const netWmName = parseQuotedStrings(
    getPropertyValue(output, "_NET_WM_NAME"),
  )[0]
  const wmName = parseQuotedStrings(getPropertyValue(output, "WM_NAME"))[0]

  return netWmName ?? wmName ?? ""
}

function parseClassName(output: string) {
  const classes = parseQuotedStrings(getPropertyValue(output, "WM_CLASS"))

  return classes[1] ?? classes[0] ?? ""
}

function parseUrgent(output: string) {
  return /urgency hint bit is set/i.test(output)
}

function readXWaylandWindowSnapshot(
  xprop: string,
  xid: string,
): XWaylandWindowSnapshot | null {
  const output = spawnText([
    xprop,
    "-id",
    xid,
    "_NET_WM_PID",
    "_NET_WM_NAME",
    "WM_NAME",
    "WM_CLASS",
    "WM_HINTS",
  ])

  if (!output) return null

  return {
    xid,
    pid: parsePid(output),
    title: parseTitle(output),
    className: parseClassName(output),
    urgent: parseUrgent(output),
  }
}

function readXWaylandWindows() {
  if (!GLib.getenv("DISPLAY")) return []

  const xprop = findXprop()

  if (!xprop) return []

  const rootOutput = spawnText([xprop, "-root", "_NET_CLIENT_LIST"])

  if (!rootOutput) return []

  return parseXids(rootOutput)
    .map((xid) => readXWaylandWindowSnapshot(xprop, xid))
    .filter((window): window is XWaylandWindowSnapshot => window !== null)
}

function toClientSnapshot(client: AstalHyprland.Client): ClientSnapshot | null {
  try {
    return {
      address: client.get_address(),
      pid: client.get_pid(),
      title: client.get_title(),
      initialTitle: client.get_initial_title(),
      className: client.get_class(),
      initialClassName: client.get_initial_class(),
      xwayland: client.get_xwayland(),
      mapped: client.get_mapped(),
    }
  } catch {
    return null
  }
}

function getMatchingScore(
  window: XWaylandWindowSnapshot,
  client: ClientSnapshot,
) {
  const windowTitle = normalize(window.title)
  const windowClassName = normalize(window.className)
  const clientTitles = new Set([
    normalize(client.title),
    normalize(client.initialTitle),
  ])
  const clientClassNames = new Set([
    normalize(client.className),
    normalize(client.initialClassName),
  ])
  let score = 0

  if (window.pid !== null && window.pid === client.pid) {
    score += 100
  }

  if (windowTitle && clientTitles.has(windowTitle)) {
    score += 20
  }

  if (windowClassName && clientClassNames.has(windowClassName)) {
    score += 15
  }

  return score
}

function findMatchingClient(
  window: XWaylandWindowSnapshot,
  clients: ClientSnapshot[],
) {
  const candidates =
    window.pid !== null
      ? clients.filter((client) => client.pid === window.pid)
      : clients
  const scoredCandidates = candidates
    .map((client) => ({
      client,
      score: getMatchingScore(window, client),
    }))
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score)

  return scoredCandidates[0]?.client ?? null
}

export function fetchXWaylandUrgentWindowAddresses(
  clients: AstalHyprland.Client[],
) {
  const xwaylandClients = clients
    .map(toClientSnapshot)
    .filter((client): client is ClientSnapshot =>
      Boolean(client?.xwayland && client.mapped),
    )

  if (xwaylandClients.length === 0) {
    return new Set<string>()
  }

  const urgentWindows = readXWaylandWindows().filter((window) => window.urgent)
  const urgentAddresses = new Set<string>()

  for (const window of urgentWindows) {
    const client = findMatchingClient(window, xwaylandClients)

    if (client) {
      urgentAddresses.add(client.address)
    }
  }

  return urgentAddresses
}
