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

const WORKSPACE_CELL_SIZE = 30
const WORKSPACE_HOVER_CLASS = "is-hovered"

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

function addWorkspaceHover(widget: Gtk.Widget) {
  const motion = Gtk.EventControllerMotion.new()

  motion.connect("notify::contains-pointer", () => {
    if (motion.containsPointer) {
      widget.add_css_class(WORKSPACE_HOVER_CLASS)
      return
    }

    widget.remove_css_class(WORKSPACE_HOVER_CLASS)
  })

  widget.add_controller(motion)
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
    workspace.urgent ? "is-urgent" : "",
    workspace.windows.length > 0 ? "has-windows" : "is-empty",
  ].filter(Boolean).join(" ")
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

  icon.set_can_target(false)

  return (
    <centerbox
      class={getWindowClassName(window)}
      widthRequest={WORKSPACE_CELL_SIZE}
      heightRequest={WORKSPACE_CELL_SIZE}
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
        canTarget={false}
      />
    ) as Gtk.Widget

    return (
      <centerbox
        class={getWorkspaceClassName(workspace)}
        widthRequest={WORKSPACE_CELL_SIZE}
        heightRequest={WORKSPACE_CELL_SIZE}
        valign={Gtk.Align.CENTER}
        centerWidget={content}
        $={(self) => {
          addWorkspaceHover(self)
          addPrimaryClick(self, () => focusWorkspace(workspace.id))
        }}
      />
    )
  }

  return (
    <box
      class={getWorkspaceClassName(workspace)}
      widthRequest={workspace.windows.length * WORKSPACE_CELL_SIZE}
      heightRequest={WORKSPACE_CELL_SIZE}
      spacing={0}
      valign={Gtk.Align.CENTER}
      $={addWorkspaceHover}
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
