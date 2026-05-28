import GLib from "gi://GLib?version=2.0"
import configJson from "inline:../../../system-control-menu.json"

type SystemControlMenuProgram = "volume" | "bluetooth"

type SystemControlMenuProgramConfig = {
  program: string | null
}

type SystemControlMenuConfig = Record<
  SystemControlMenuProgram,
  SystemControlMenuProgramConfig
>

const DEFAULT_SYSTEM_CONTROL_MENU_CONFIG: SystemControlMenuConfig = {
  volume: {
    program: null,
  },
  bluetooth: {
    program: null,
  },
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function parseProgramConfig(
  value: unknown,
): SystemControlMenuProgramConfig {
  if (!isRecord(value)) {
    return {
      program: null,
    }
  }

  return {
    program: typeof value.program === "string" && value.program.trim()
      ? value.program
      : null,
  }
}

function parseSystemControlMenuConfig(json: string): SystemControlMenuConfig {
  try {
    const parsed = JSON.parse(json) as unknown

    if (!isRecord(parsed)) {
      console.error("Invalid system control menu config", parsed)
      return DEFAULT_SYSTEM_CONTROL_MENU_CONFIG
    }

    return {
      volume: parseProgramConfig(parsed.volume),
      bluetooth: parseProgramConfig(parsed.bluetooth),
    }
  } catch (error) {
    console.error("Failed to parse system control menu config", error)
    return DEFAULT_SYSTEM_CONTROL_MENU_CONFIG
  }
}

function parseCommand(command: string) {
  const [parsed, argv] = GLib.shell_parse_argv(command)

  if (!parsed || !argv || argv.length === 0) {
    return null
  }

  return argv
}

function spawn(argv: string[]) {
  const [spawned, pid] = GLib.spawn_async(
    null,
    argv,
    null,
    GLib.SpawnFlags.SEARCH_PATH |
      GLib.SpawnFlags.STDIN_FROM_DEV_NULL |
      GLib.SpawnFlags.STDOUT_TO_DEV_NULL |
      GLib.SpawnFlags.STDERR_TO_DEV_NULL,
    null,
  )

  if (pid !== null) {
    GLib.spawn_close_pid(pid)
  }

  return spawned
}

const systemControlMenuConfig = parseSystemControlMenuConfig(configJson)

export function launchSystemControlMenuProgram(
  program: SystemControlMenuProgram,
) {
  const command = systemControlMenuConfig[program].program

  if (!command) return false

  try {
    const argv = parseCommand(command)

    if (!argv) {
      console.error(`Invalid system control menu command: ${command}`)
      return false
    }

    return spawn(argv)
  } catch (error) {
    console.error(`Failed to launch system control menu program: ${command}`, error)
    return false
  }
}
