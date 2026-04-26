import { Accessor } from "ags"
import type Gdk from "gi://Gdk?version=4.0"
import { Astal, Gtk } from "ags/gtk4"
import Icon from "../icon"
import { addCloseOnEscape } from "../menu-escape"

export type ShutdownConfirmationAction = "shutdown" | "restart" | "logout"

type ShutdownConfirmationOverlayProps = {
  gdkmonitor?: Gdk.Monitor
  type:
    | ShutdownConfirmationAction
    | null
    | Accessor<ShutdownConfirmationAction | null>
  visible?: boolean | Accessor<boolean>
  onCancel?: () => void
  onConfirm?: (type: ShutdownConfirmationAction) => void
}

type ActionCopy = {
  className: string
  confirmLabel: string
  description: string
  icon: string
  title: string
}

const ACTION_COPY: Record<ShutdownConfirmationAction, ActionCopy> = {
  shutdown: {
    className: "is-shutdown",
    confirmLabel: "Power Off",
    description: "Shut down this computer and end the current session.",
    icon: "power_settings_new",
    title: "Power Off",
  },
  restart: {
    className: "is-restart",
    confirmLabel: "Restart",
    description: "Restart this computer and end the current session.",
    icon: "restart_alt",
    title: "Restart",
  },
  logout: {
    className: "is-logout",
    confirmLabel: "Log Out",
    description: "Log out of the current Hyprland session.",
    icon: "logout",
    title: "Log Out",
  },
}
const RENDER_FALLBACK_ACTION: ShutdownConfirmationAction = "logout"

function isAccessor<T>(value: T | Accessor<T>): value is Accessor<T> {
  return value instanceof Accessor
}

function readAction(
  type:
    | ShutdownConfirmationAction
    | null
    | Accessor<ShutdownConfirmationAction | null>,
) {
  return isAccessor(type) ? type.peek() : type
}

function mapRenderAction<T>(
  type:
    | ShutdownConfirmationAction
    | null
    | Accessor<ShutdownConfirmationAction | null>,
  mapper: (type: ShutdownConfirmationAction) => T,
) {
  return isAccessor(type)
    ? type.as((currentType) => mapper(currentType ?? RENDER_FALLBACK_ACTION))
    : mapper(type ?? RENDER_FALLBACK_ACTION)
}

function hasAction(
  type:
    | ShutdownConfirmationAction
    | null
    | Accessor<ShutdownConfirmationAction | null>,
) {
  return isAccessor(type)
    ? type.as((currentType) => currentType !== null)
    : type !== null
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
}

export default function ShutdownConfirmationOverlay({
  gdkmonitor,
  type,
  visible = true,
  onCancel,
  onConfirm,
}: ShutdownConfirmationOverlayProps) {
  const monitorProps = gdkmonitor ? { gdkmonitor } : {}
  const cancel = () => onCancel?.()
  const confirm = () => {
    const action = readAction(type)

    if (!action) {
      cancel()
      return
    }

    onConfirm?.(action)
  }
  const scrim = (
    <box
      class="shutdown-confirmation-overlay-scrim"
      canTarget
      hexpand
      vexpand
      $={(self) => addPrimaryClick(self, cancel)}
    />
  ) as Gtk.Widget
  const card = (
    <box
      class={mapRenderAction(
        type,
        (action) => `shutdown-confirmation-overlay-card ${ACTION_COPY[action].className}`,
      )}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={18}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
    >
      <box
        class="shutdown-confirmation-overlay-heading"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        halign={Gtk.Align.CENTER}
      >
        <centerbox
          class="shutdown-confirmation-overlay-icon-container"
          centerWidget={(
            <Icon
              name={mapRenderAction(type, (action) => ACTION_COPY[action].icon)}
              class="shutdown-confirmation-overlay-icon"
              size={34}
            />
          ) as Gtk.Widget}
        />
        <label
          class="shutdown-confirmation-overlay-title text"
          label={mapRenderAction(type, (action) => ACTION_COPY[action].title)}
        />
        <label
          class="shutdown-confirmation-overlay-description text"
          label={mapRenderAction(type, (action) => ACTION_COPY[action].description)}
          wrap
          widthChars={36}
          xalign={0.5}
          justify={Gtk.Justification.CENTER}
        />
      </box>
      <box
        class="shutdown-confirmation-overlay-actions"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={10}
        halign={Gtk.Align.CENTER}
      >
        <button
          class="shutdown-confirmation-overlay-button is-cancel"
          hasFrame={false}
          focusOnClick={false}
          child={(
            <label
              class="shutdown-confirmation-overlay-button-label text"
              label="Cancel"
            />
          ) as Gtk.Widget}
          $={(self) => self.connect("clicked", cancel)}
        />
        <button
          class={mapRenderAction(
            type,
            (action) =>
              `shutdown-confirmation-overlay-button is-confirm ${ACTION_COPY[action].className}`,
          )}
          sensitive={hasAction(type)}
          hasFrame={false}
          focusOnClick={false}
          child={(
            <label
              class="shutdown-confirmation-overlay-button-label text"
              label={mapRenderAction(
                type,
                (action) => ACTION_COPY[action].confirmLabel,
              )}
            />
          ) as Gtk.Widget}
          $={(self) => self.connect("clicked", confirm)}
        />
      </box>
    </box>
  ) as Gtk.Widget
  const shell = (
    <overlay
      class="shutdown-confirmation-overlay-shell"
      canTarget
      hexpand
      vexpand
      child={scrim}
      $={(self) => {
        self.add_overlay(card)
        self.set_measure_overlay(card, false)
        addCloseOnEscape(self, cancel, { grabFocus: true })
      }}
    />
  ) as Gtk.Widget

  return (
    <window
      {...monitorProps}
      name="shutdown-confirmation-overlay"
      namespace="shutdown-confirmation-overlay"
      class="shutdown-confirmation-overlay-window"
      visible={visible}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM
      }
    >
      {shell}
    </window>
  )
}
