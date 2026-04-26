export type IpcResponse = string | void

export type IpcHandler = {
  name: string
  handler: (args: string[]) => IpcResponse
}
