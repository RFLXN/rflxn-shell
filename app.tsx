import { Fragment } from "ags"
import { Gtk } from "ags/gtk4"
import app from "ags/gtk4/app"
import { handleIpcRequest } from "./ipc"
import Layout from "./layout"
import style from "./style.scss"

app.gtkTheme = "Adwaita"

function addWindows(node: unknown) {
  if (node instanceof Gtk.Window) {
    app.add_window(node)
    return
  }

  if (node instanceof Fragment || Array.isArray(node)) {
    for (const child of node) {
      addWindows(child)
    }
  }
}

app.start({
  css: style,
  requestHandler: handleIpcRequest,
  main() {
    addWindows(Layout())
  },
})
