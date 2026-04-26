import { For } from "ags"
import { Gtk } from "ags/gtk4"
import AppIcon from "../../../app-icon"
import Icon from "../../../icon"
import { refetchHyprland, workspaces } from "../store"
import type {
  HyprlandWindowSnapshot,
  HyprlandWorkspaceSnapshot,
} from "../../../../utils/hyprland/workspaces"
import {
  focusHyprlandWindow,
  focusHyprlandWorkspace,
} from "../../../../utils/hyprland/workspaces"

type WorkspacesWidgetProps = {
  monitorName?: string
}

function addPrimaryClick(widget: Gtk.Widget, onClick: () => void) {
  const click = Gtk.GestureClick.new()

  click.set_button(1)
  click.connect("released", (gesture, nPress) => {
    if (nPress !== 1) return

    gesture.set_state(Gtk.EventSequenceState.CLAIMED)
    onClick()
  })

  widget.add_controller(click)
  widget.set_cursor_from_name("pointer")
}

function focusWorkspace(id: number) {
  focusHyprlandWorkspace(id)
  refetchHyprland()
}

function focusWindow(address: string) {
  focusHyprlandWindow(address)
  refetchHyprland()
}

function getWorkspaceClassName(workspace: HyprlandWorkspaceSnapshot) {
  return [
    "widget-workspaces-item",
    `is-${workspace.status}`,
    workspace.windows.length > 0 ? "has-windows" : "is-empty",
  ].join(" ")
}

function getWindowClassName(window: HyprlandWindowSnapshot) {
  return [
    "widget-workspaces-window",
    `is-${window.status}`,
  ].join(" ")
}

function WorkspaceWindow({ window }: { window: HyprlandWindowSnapshot }) {
  const icon =
    AppIcon({
      name: window.icon,
      class: "widget-workspaces-window-icon",
      size: "css",
    }) ??
    (<Icon
      name="web_asset"
      class="widget-workspaces-window-icon"
      size="css"
    /> as Gtk.Widget)

  return (
    <centerbox
      class={getWindowClassName(window)}
      valign={Gtk.Align.CENTER}
      centerWidget={icon}
      $={(self) => addPrimaryClick(self, () => focusWindow(window.address))}
    />
  )
}

function WorkspaceItem({ workspace }: { workspace: HyprlandWorkspaceSnapshot }) {
  const isEmpty = workspace.windows.length === 0

  if (isEmpty) {
    const content = (
      <box
        class="widget-workspaces-empty-dot"
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
      />
    ) as Gtk.Widget

    return (
      <centerbox
        class={getWorkspaceClassName(workspace)}
        valign={Gtk.Align.CENTER}
        centerWidget={content}
        $={(self) => addPrimaryClick(self, () => focusWorkspace(workspace.id))}
      />
    )
  }

  return (
    <box
      class={getWorkspaceClassName(workspace)}
      spacing={0}
      valign={Gtk.Align.CENTER}
    >
      {workspace.windows.map((window) => <WorkspaceWindow window={window} />)}
    </box>
  )
}

export default function WorkspacesWidget({
  monitorName,
}: WorkspacesWidgetProps) {
  const filteredWorkspaces = workspaces.as((items) =>
    monitorName
      ? items.filter((workspace) => workspace.monitor === monitorName)
      : items,
  )

  return (
    <box class="widget-workspaces" valign={Gtk.Align.CENTER}>
      <For each={filteredWorkspaces}>
        {(workspace) => <WorkspaceItem workspace={workspace} />}
      </For>
    </box>
  )
}
