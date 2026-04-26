import type { IpcHandler } from "./handler"
import { launcherIpcHandler } from "./launcher"

type IpcResponder = (response: string) => void

const ipcHandlers: IpcHandler[] = [
  launcherIpcHandler,
]

function formatAvailableHandlers() {
  return ipcHandlers.map((handler) => handler.name).join(", ")
}

export function handleIpcRequest(argv: string[], res: IpcResponder) {
  const [name, ...args] = argv

  if (!name) {
    res(`usage: ags request <${formatAvailableHandlers()}> ...`)
    return
  }

  const ipcHandler = ipcHandlers.find((handler) => handler.name === name)

  if (!ipcHandler) {
    res(`unknown request: ${name}`)
    return
  }

  try {
    res(ipcHandler.handler(args) ?? "ok")
  } catch (error) {
    console.error(`Failed to handle IPC request: ${argv.join(" ")}`, error)
    res(`error: failed to handle request ${name}`)
  }
}
