import { createState } from "ags"
import AstalApps from "gi://AstalApps?version=0.1"
import GLib from "gi://GLib?version=2.0"
import { closeAppLauncher } from "../../global-store"

const MAX_RESULTS = 16
const DESKTOP_ENTRY_EXTENSION = ".desktop"
const FALLBACK_PROGRAM_DIRS = ["/run/current-system/sw/bin", "/usr/bin"]

const apps = AstalApps.Apps.new()

const [appLauncherQuery, setAppLauncherQueryState] = createState("")
const [appLauncherResults, setAppLauncherResults] = createState<
  AstalApps.Application[]
>([])
const [appLauncherActiveIndex, setAppLauncherActiveIndexState] = createState(-1)

function compareDefaultResults(
  left: AstalApps.Application,
  right: AstalApps.Application,
) {
  const frequencyDiff = right.get_frequency() - left.get_frequency()

  if (frequencyDiff !== 0) return frequencyDiff

  return getApplicationName(left).localeCompare(getApplicationName(right))
}

function normalizeText(value: string | null | undefined) {
  return value?.trim() ?? ""
}

function getApplicationName(app: AstalApps.Application) {
  return normalizeText(app.get_name()) || normalizeText(app.get_entry())
}

function stripDesktopExtension(value: string) {
  return value.endsWith(DESKTOP_ENTRY_EXTENSION)
    ? value.slice(0, -DESKTOP_ENTRY_EXTENSION.length)
    : value
}

function unique(values: string[]) {
  return Array.from(new Set(values.filter(Boolean)))
}

function getBasename(value: string) {
  const parts = value.split("/")

  return parts[parts.length - 1] ?? value
}

function findProgram(program: string) {
  const pathProgram = GLib.find_program_in_path(program)

  if (pathProgram) return pathProgram

  return (
    FALLBACK_PROGRAM_DIRS.map((dir) => `${dir}/${program}`).find((candidate) =>
      GLib.file_test(candidate, GLib.FileTest.IS_EXECUTABLE),
    ) ?? null
  )
}

function spawnAndCheck(argv: string[]) {
  const [spawned, , , waitStatus] = GLib.spawn_sync(
    null,
    argv,
    null,
    GLib.SpawnFlags.STDIN_FROM_DEV_NULL,
    null,
  )

  if (!spawned) return false

  try {
    return GLib.spawn_check_wait_status(waitStatus)
  } catch {
    return false
  }
}

function getUwsmLaunchTargets(app: AstalApps.Application) {
  const desktopEntry = normalizeText(app.get_entry())

  if (!desktopEntry) return []

  const basename = getBasename(desktopEntry)

  return unique([
    desktopEntry,
    stripDesktopExtension(desktopEntry),
    basename,
    stripDesktopExtension(basename),
  ])
}

function stripDesktopExecFieldCodes(exec: string) {
  return exec
    .replaceAll("%%", "\0PERCENT\0")
    .replace(/%[fFuUdDnNickvm]/g, "")
    .replaceAll("\0PERCENT\0", "%")
    .trim()
}

function getExecutableArgv(app: AstalApps.Application) {
  const executable = stripDesktopExecFieldCodes(
    normalizeText(app.get_executable()),
  )

  if (!executable) return null

  const [parsed, argv] = GLib.shell_parse_argv(executable)

  return parsed && argv && argv.length > 0 ? argv : null
}

function queryApplications(query: string) {
  const normalizedQuery = query.trim()

  if (normalizedQuery) {
    return apps.fuzzy_query(normalizedQuery).slice(0, MAX_RESULTS)
  }

  return apps
    .get_list()
    .slice()
    .sort(compareDefaultResults)
    .slice(0, MAX_RESULTS)
}

function clampActiveIndex(index: number, results = appLauncherResults.peek()) {
  if (results.length === 0) return -1

  return Math.max(0, Math.min(index, results.length - 1))
}

function refreshAppLauncherResults() {
  const nextResults = queryApplications(appLauncherQuery.peek())

  setAppLauncherResults(nextResults)
  setAppLauncherActiveIndexState(
    clampActiveIndex(appLauncherActiveIndex.peek(), nextResults),
  )
}

function launchWithUwsm(app: AstalApps.Application) {
  const uwsm = findProgram("uwsm")

  if (!uwsm) return false

  for (const target of getUwsmLaunchTargets(app)) {
    if (spawnAndCheck([uwsm, "app", "-t", "service", "-S", "both", target])) {
      return true
    }
  }

  return false
}

function launchWithSystemdRun(app: AstalApps.Application) {
  const systemdRun = findProgram("systemd-run")
  const executableArgv = getExecutableArgv(app)

  if (!systemdRun || !executableArgv) return false

  return spawnAndCheck([
    systemdRun,
    "--user",
    "--collect",
    "--quiet",
    "--slice=app-graphical.slice",
    "--",
    ...executableArgv,
  ])
}

function launchDetachedApplication(app: AstalApps.Application) {
  try {
    // app.launch()/GIO launch can leave GUI apps tied to the AGS process tree.
    // Run apps through user systemd services instead, so closing AGS does not
    // terminate applications started from the launcher.
    return launchWithUwsm(app) || launchWithSystemdRun(app)
  } catch (error) {
    console.error(`Failed to launch ${getApplicationName(app)}`, error)
    return false
  }
}

export function setAppLauncherQuery(query: string) {
  const nextResults = queryApplications(query)

  setAppLauncherQueryState(query)
  setAppLauncherResults(nextResults)
  setAppLauncherActiveIndexState(nextResults.length > 0 ? 0 : -1)
}

export function clearAppLauncherQuery() {
  setAppLauncherQuery("")
}

export function launchAppLauncherApplication(app: AstalApps.Application) {
  const launched = launchDetachedApplication(app)

  if (launched) {
    app.set_frequency(app.get_frequency() + 1)
    clearAppLauncherQuery()
    closeAppLauncher()
  }

  return launched
}

export function launchFirstAppLauncherResult() {
  const [firstResult] = appLauncherResults.peek()

  if (!firstResult) return false

  return launchAppLauncherApplication(firstResult)
}

export function setAppLauncherActiveIndex(index: number) {
  setAppLauncherActiveIndexState(clampActiveIndex(index))
}

export function moveAppLauncherActiveIndex(offset: number) {
  const results = appLauncherResults.peek()

  if (results.length === 0) {
    setAppLauncherActiveIndexState(-1)
    return
  }

  const currentIndex = appLauncherActiveIndex.peek()
  const baseIndex = currentIndex < 0 ? 0 : currentIndex
  const nextIndex = (baseIndex + offset + results.length) % results.length

  setAppLauncherActiveIndexState(nextIndex)
}

export function launchActiveAppLauncherResult() {
  const activeIndex = appLauncherActiveIndex.peek()
  const activeResult = appLauncherResults.peek()[activeIndex]

  if (!activeResult) return false

  return launchAppLauncherApplication(activeResult)
}

apps.set_show_hidden(false)
apps.reload()
apps.connect("notify::list", refreshAppLauncherResults)
refreshAppLauncherResults()

export { appLauncherActiveIndex, appLauncherQuery, appLauncherResults }
