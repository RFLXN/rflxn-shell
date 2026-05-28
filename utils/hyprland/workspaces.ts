import AstalApps from "gi://AstalApps?version=0.1"
import AstalHyprland from "gi://AstalHyprland?version=0.1"

export type HyprlandWorkspaceStatus =
  | "focused"
  | "active"
  | "occupied"
  | "empty"

export type HyprlandWindowStatus = "focused" | "hidden" | "normal"

export type HyprlandWindowSnapshot = {
  address: string
  name: string
  icon: string | null
  status: HyprlandWindowStatus
}

export type HyprlandWorkspaceSnapshot = {
  id: number
  status: HyprlandWorkspaceStatus
  monitor: string
  urgent: boolean
  windows: HyprlandWindowSnapshot[]
}

export type FetchHyprlandWorkspacesOptions = {
  urgentWindowAddresses?: ReadonlySet<string>
}

let apps: AstalApps.Apps | null = null

function getHyprland() {
  return AstalHyprland.get_default()
}

function syncMonitors(hyprland: AstalHyprland.Hyprland) {
  return new Promise<void>((resolve, reject) => {
    try {
      hyprland.sync_monitors((_, result) => {
        try {
          hyprland.sync_monitors_finish(result)
          resolve()
        } catch (error) {
          reject(error)
        }
      })
    } catch (error) {
      reject(error)
    }
  })
}

function syncWorkspaces(hyprland: AstalHyprland.Hyprland) {
  return new Promise<void>((resolve, reject) => {
    try {
      hyprland.sync_workspaces((_, result) => {
        try {
          hyprland.sync_workspaces_finish(result)
          resolve()
        } catch (error) {
          reject(error)
        }
      })
    } catch (error) {
      reject(error)
    }
  })
}

function syncClients(hyprland: AstalHyprland.Hyprland) {
  return new Promise<void>((resolve, reject) => {
    try {
      hyprland.sync_clients((_, result) => {
        try {
          hyprland.sync_clients_finish(result)
          resolve()
        } catch (error) {
          reject(error)
        }
      })
    } catch (error) {
      reject(error)
    }
  })
}

function getApps() {
  apps ??= AstalApps.Apps.new()
  return apps
}

function normalize(value: string | null | undefined) {
  if (typeof value !== "string") return ""

  return value.trim().toLowerCase()
}

function stripDesktopExtension(entry: string | null | undefined) {
  const normalized = normalize(entry)

  return normalized.endsWith(".desktop") ? normalized.slice(0, -8) : normalized
}

function getExecutableName(executable: string | null | undefined) {
  const command = normalize(executable).split(/\s+/)[0] ?? ""
  const parts = command.split("/")

  return parts[parts.length - 1] ?? command
}

function getSteamAppIconName(clientClassNames: Set<string>) {
  for (const className of clientClassNames) {
    const match = className.match(/^steam_app_(\d+)$/)

    if (match?.[1]) {
      return `steam_icon_${match[1]}`
    }
  }

  return null
}

function isSteamGameLauncher(app: AstalApps.Application) {
  return normalize(app.get_executable()).includes("steam://rungameid/")
}

function matchesClientAppIdentity(
  app: AstalApps.Application,
  clientClassNames: Set<string>,
) {
  const candidates = [
    normalize(app.get_wm_class()),
    stripDesktopExtension(app.get_entry()),
    normalize(app.get_name()),
  ].filter(Boolean)

  return candidates.some((candidate) => clientClassNames.has(candidate))
}

function matchesClientAppExecutable(
  app: AstalApps.Application,
  clientClassNames: Set<string>,
) {
  if (isSteamGameLauncher(app)) {
    return false
  }

  const executableName = getExecutableName(app.get_executable())

  return Boolean(executableName) && clientClassNames.has(executableName)
}

function getClientIcon(client: AstalHyprland.Client) {
  const clientClassNames = new Set(
    [
      client.get_initial_class(),
      client.get_class(),
    ]
      .map(normalize)
      .filter(Boolean),
  )

  if (clientClassNames.size === 0) {
    return null
  }

  const steamAppIconName = getSteamAppIconName(clientClassNames)

  if (steamAppIconName) {
    return steamAppIconName
  }

  const appList = getApps().get_list()
  const app =
    appList.find((candidate) =>
      matchesClientAppIdentity(candidate, clientClassNames),
    ) ??
    appList.find((candidate) =>
      matchesClientAppExecutable(candidate, clientClassNames),
    )

  return app?.get_icon_name() || null
}

function getWindowStatus(
  client: AstalHyprland.Client,
  focusedWindowAddress: string | null,
): HyprlandWindowStatus {
  if (client.get_address() === focusedWindowAddress) return "focused"
  if (client.get_hidden() || !client.get_mapped()) return "hidden"
  return "normal"
}

function toWindowSnapshot(
  client: AstalHyprland.Client,
  focusedWindowAddress: string | null,
): HyprlandWindowSnapshot {
  return {
    address: client.get_address(),
    name: client.get_title() || client.get_class(),
    icon: getClientIcon(client),
    status: getWindowStatus(client, focusedWindowAddress),
  }
}

function getWorkspaceStatus({
  focused,
  active,
  occupied,
}: {
  focused: boolean
  active: boolean
  occupied: boolean
}): HyprlandWorkspaceStatus {
  if (focused) return "focused"
  if (active) return "active"
  if (occupied) return "occupied"
  return "empty"
}

function toWorkspaceSnapshot(
  workspace: AstalHyprland.Workspace,
  activeWorkspaceIds: Set<number>,
  focusedWorkspaceId: number,
  focusedWindowAddress: string | null,
  urgentWindowAddresses: ReadonlySet<string>,
): HyprlandWorkspaceSnapshot {
  const id = workspace.get_id()
  const focused = id === focusedWorkspaceId
  const active = activeWorkspaceIds.has(id)
  const windows = workspace
    .get_clients()
    .map((client) => toWindowSnapshot(client, focusedWindowAddress))
  const occupied = windows.length > 0
  const urgent =
    !focused && windows.some((window) => urgentWindowAddresses.has(window.address))

  return {
    id,
    status: getWorkspaceStatus({ focused, active, occupied }),
    monitor: workspace.get_monitor().get_name(),
    urgent,
    windows,
  }
}

function byWorkspaceId(a: HyprlandWorkspaceSnapshot, b: HyprlandWorkspaceSnapshot) {
  return a.id - b.id
}

function isNormalWorkspace(workspace: AstalHyprland.Workspace) {
  const id = workspace.get_id()
  const name = normalize(workspace.get_name())

  return id > 0 && name !== "special" && !name.startsWith("special:")
}

export async function fetchHyprlandWorkspaces({
  urgentWindowAddresses = new Set<string>(),
}: FetchHyprlandWorkspacesOptions = {}): Promise<
  HyprlandWorkspaceSnapshot[]
> {
  const hyprland = getHyprland()

  await syncMonitors(hyprland)
  await syncWorkspaces(hyprland)
  await syncClients(hyprland)

  const focusedWorkspaceId = hyprland.get_focused_workspace().get_id()
  const focusedWindow = hyprland.get_focused_client() as
    | AstalHyprland.Client
    | null
  const focusedWindowAddress = focusedWindow?.get_address() ?? null
  const activeWorkspaceIds = new Set(
    hyprland
      .get_monitors()
      .map((monitor) => monitor.get_active_workspace().get_id()),
  )

  return hyprland
    .get_workspaces()
    .filter(isNormalWorkspace)
    .map((workspace) =>
      toWorkspaceSnapshot(
        workspace,
        activeWorkspaceIds,
        focusedWorkspaceId,
        focusedWindowAddress,
        urgentWindowAddresses,
      ),
    )
    .sort(byWorkspaceId)
}

export function focusHyprlandWorkspace(id: number) {
  getHyprland().get_workspace(id).focus()
}

export function focusHyprlandWindow(address: string) {
  const hyprland = getHyprland()
  const client = hyprland.get_client(address)

  if (client) {
    client.focus()
    return
  }

  hyprland.dispatch("focuswindow", `address:${address}`)
}
