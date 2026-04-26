import {
  closeAppLauncher,
  openAppLauncher,
  toggleAppLauncher,
} from "../components/global-store"
import type { IpcHandler } from "./handler"

export const launcherIpcHandler: IpcHandler = {
  name: "launcher",
  handler(args) {
    const [action] = args

    if (action === "toggle") {
      toggleAppLauncher()
      return "launcher toggled"
    }

    if (action === "open") {
      openAppLauncher()
      return "launcher opened"
    }

    if (action === "close") {
      closeAppLauncher()
      return "launcher closed"
    }

    return "usage: ags request launcher <toggle|open|close>"
  },
}
