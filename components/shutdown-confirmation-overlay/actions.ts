import GLib from "gi://GLib?version=2.0"
import type { ShutdownConfirmationAction } from "."

const FALLBACK_PROGRAM_DIRS = ["/run/current-system/sw/bin", "/usr/bin", "/bin"]

function findProgram(program: string) {
  const pathProgram = GLib.find_program_in_path(program)

  if (pathProgram) return pathProgram

  return (
    FALLBACK_PROGRAM_DIRS.map((dir) => `${dir}/${program}`).find((candidate) =>
      GLib.file_test(candidate, GLib.FileTest.IS_EXECUTABLE),
    ) ?? null
  )
}

function spawn(argv: string[]) {
  const [spawned, pid] = GLib.spawn_async(
    null,
    argv,
    null,
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

function runSystemctlAction(action: "poweroff" | "reboot") {
  const systemctl = findProgram("systemctl")

  if (!systemctl) return false

  return spawn([systemctl, action])
}

function runLogoutAction() {
  const sh = findProgram("sh")
  const uwsm = findProgram("uwsm")
  const hyprctl = findProgram("hyprctl")

  if (!sh) return false

  if (uwsm && hyprctl) {
    return spawn([sh, "-c", `"${uwsm}" stop || "${hyprctl}" dispatch exit`])
  }

  if (uwsm) {
    return spawn([uwsm, "stop"])
  }

  if (hyprctl) {
    return spawn([hyprctl, "dispatch", "exit"])
  }

  return false
}

export function executeShutdownConfirmationAction(
  action: ShutdownConfirmationAction,
) {
  try {
    if (action === "shutdown") return runSystemctlAction("poweroff")
    if (action === "restart") return runSystemctlAction("reboot")

    return runLogoutAction()
  } catch (error) {
    console.error(`Failed to execute ${action}`, error)
    return false
  }
}
