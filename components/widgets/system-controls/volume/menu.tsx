import { onCleanup } from "ags"
import { Astal, Gtk } from "ags/gtk4"
import Icon from "../../../icon"
import { launchSystemControlMenuProgram } from "../menu-config"
import { closeSystemControlsMenu } from "../store"
import {
  setVolumeMenuDeviceDefault,
  setVolumeMenuDeviceMuted,
  setVolumeMenuDeviceVolume,
  volumeMenuState,
  type VolumeMenuDevice,
  type VolumeMenuDeviceKind,
  type VolumeMenuState,
} from "./menu-store"

type VolumeMenuSectionConfig = {
  title: string
  kind: VolumeMenuDeviceKind
  devices: VolumeMenuDevice[]
}

function clearBox(box: Gtk.Box) {
  let child = box.get_first_child()

  while (child) {
    const next = child.get_next_sibling()

    box.remove(child)
    child = next
  }
}

function getDeviceLabel(device: VolumeMenuDevice) {
  return device.description || device.name || `Device ${device.id}`
}

function getDefaultOutputDevice(state: VolumeMenuState) {
  return state.outputDevices.find((device) => device.isDefault)
    || state.outputDevices[0]
    || null
}

function getVolumeStatusDescription(device: VolumeMenuDevice | null) {
  if (!device) {
    return "No output devices"
  }

  if (device.muted) {
    return `${getDeviceLabel(device)} - muted`
  }

  return `${getDeviceLabel(device)} - ${device.volumePercent}%`
}

function getVolumeStatusIconName(device: VolumeMenuDevice | null) {
  if (!device) return "volume_off"
  if (device.muted) return "volume_mute"
  if (device.volumePercent <= 0) return "volume_off"
  if (device.volumePercent >= 50) return "volume_up"

  return "volume_down"
}

function VolumeStatus({ state }: { state: VolumeMenuState }) {
  const defaultOutput = getDefaultOutputDevice(state)

  return (
    <box
      class="widget-system-controls-volume-menu-status"
      orientation={Gtk.Orientation.HORIZONTAL}
      spacing={10}
      hexpand
    >
      <button
        class="widget-system-controls-volume-menu-status-icon-container"
        widthRequest={34}
        heightRequest={34}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        hasFrame={false}
        focusOnClick={false}
        child={(
          <centerbox
            widthRequest={34}
            heightRequest={34}
            centerWidget={(
              <Icon
                name={getVolumeStatusIconName(defaultOutput)}
                class="widget-system-controls-volume-menu-status-icon"
                size={20}
              />
            ) as Gtk.Widget}
          />
        ) as Gtk.Widget}
        $={(self) => {
          self.connect("clicked", () => {
            if (launchSystemControlMenuProgram("volume")) {
              closeSystemControlsMenu()
            }
          })
        }}
      />
      <box
        class="widget-system-controls-volume-menu-status-copy"
        orientation={Gtk.Orientation.VERTICAL}
        hexpand
        valign={Gtk.Align.CENTER}
      >
        <label
          class="widget-system-controls-volume-menu-status-title text"
          label="Volume"
          xalign={0}
        />
        <label
          class="widget-system-controls-volume-menu-status-description text"
          label={getVolumeStatusDescription(defaultOutput)}
          xalign={0}
        />
      </box>
    </box>
  )
}

function createDefaultButton(
  kind: VolumeMenuDeviceKind,
  device: VolumeMenuDevice,
) {
  const selector = (
    <box
      class={device.isDefault
        ? "widget-system-controls-volume-menu-default is-default"
        : "widget-system-controls-volume-menu-default"}
      widthRequest={18}
      heightRequest={18}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
    >
      <centerbox
        class="widget-system-controls-volume-menu-default-container"
        widthRequest={18}
        heightRequest={18}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        centerWidget={(
          <box
            class="widget-system-controls-volume-menu-default-indicator"
            widthRequest={10}
            heightRequest={10}
            halign={Gtk.Align.CENTER}
            valign={Gtk.Align.CENTER}
          />
        ) as Gtk.Widget}
      />
    </box>
  ) as Gtk.Box
  const click = Gtk.GestureClick.new()

  click.connect("released", () => {
    if (device.isDefault) return

    setVolumeMenuDeviceDefault(kind, device.id)
  })

  selector.add_controller(click)
  selector.set_tooltip_text("Set as default device")

  return selector
}

function createMuteButton(
  kind: VolumeMenuDeviceKind,
  device: VolumeMenuDevice,
) {
  const icon = (
    <Icon
      name={device.muted ? "volume_mute" : "volume_down"}
      class="widget-system-controls-volume-menu-mute-icon"
      size={18}
    />
  ) as Gtk.Widget
  const button = (
    <button
      class={device.muted
        ? "widget-system-controls-volume-menu-mute is-muted"
        : "widget-system-controls-volume-menu-mute"}
      widthRequest={28}
      heightRequest={28}
      valign={Gtk.Align.CENTER}
      hasFrame={false}
      focusOnClick={false}
      child={(
        <centerbox
          class="widget-system-controls-volume-menu-mute-icon-container"
          widthRequest={28}
          heightRequest={28}
          valign={Gtk.Align.CENTER}
          centerWidget={icon}
        />
      ) as Gtk.Widget}
      $={(self) => {
        self.connect("clicked", () => {
          setVolumeMenuDeviceMuted(kind, device.id, !device.muted)
        })
      }}
    />
  ) as Gtk.Button

  button.set_tooltip_text(device.muted ? "Unmute" : "Mute")

  return button
}

function VolumeDeviceRow({
  kind,
  device,
  defaultButton,
}: {
  kind: VolumeMenuDeviceKind
  device: VolumeMenuDevice
  defaultButton: Gtk.Widget
}) {
  const muteButton = createMuteButton(kind, device)
  const sliderValue = Math.max(0, Math.min(device.volume, 1))
  const percentLabel = (
    <label
      class="widget-system-controls-volume-menu-percent text"
      label={`${device.volumePercent}%`}
      widthRequest={42}
      xalign={1}
    />
  ) as Gtk.Label

  return (
    <box
      class="widget-system-controls-volume-menu-device"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
      hexpand
    >
      <box
        class="widget-system-controls-volume-menu-device-header"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={8}
        hexpand
      >
        {defaultButton}
        <label
          class="widget-system-controls-volume-menu-device-name text"
          label={getDeviceLabel(device)}
          xalign={0}
          hexpand
        />
      </box>
      <box
        class="widget-system-controls-volume-menu-device-control"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={6}
        hexpand
      >
        {muteButton}
        <slider
          class="widget-system-controls-volume-menu-slider"
          min={0}
          max={1}
          step={0.01}
          page={0.05}
          value={sliderValue}
          drawValue={false}
          heightRequest={18}
          hexpand
          valign={Gtk.Align.CENTER}
          $={(self: Astal.Slider) => {
            self.connect("notify::value", () => {
              const value = self.get_value()

              percentLabel.set_label(`${Math.round(Math.max(0, value) * 100)}%`)
              setVolumeMenuDeviceVolume(kind, device.id, value)
            })
          }}
        />
        {percentLabel}
      </box>
    </box>
  )
}

function VolumeMenuSection({
  title,
  kind,
  devices,
}: VolumeMenuSectionConfig) {
  const section = (
    <box
      class="widget-system-controls-volume-menu-section"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={4}
      hexpand
    >
      <label
        class="widget-system-controls-volume-menu-section-title text"
        label={title}
        xalign={0}
      />
    </box>
  ) as Gtk.Box
  if (devices.length === 0) {
    section.append(
      (
        <label
          class="widget-system-controls-volume-menu-empty text"
          label="No devices"
          xalign={0}
        />
      ) as Gtk.Widget,
    )
    return section
  }

  for (const device of devices) {
    const defaultButton = createDefaultButton(kind, device)

    section.append(
      (
        <VolumeDeviceRow
          kind={kind}
          device={device}
          defaultButton={defaultButton}
        />
      ) as Gtk.Widget,
    )
  }

  return section
}

export default function VolumeMenu() {
  return (
    <box
      class="widget-system-controls-volume-menu"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
      hexpand
      $={(self) => {
        const render = () => {
          const state = volumeMenuState.peek()

          clearBox(self)
          self.append((<VolumeStatus state={state} />) as Gtk.Widget)
          self.append(
            VolumeMenuSection({
              title: "Output",
              kind: "output",
              devices: state.outputDevices,
            }),
          )
          self.append(
            VolumeMenuSection({
              title: "Input",
              kind: "input",
              devices: state.inputDevices,
            }),
          )
        }

        render()
        onCleanup(volumeMenuState.subscribe(render))
      }}
    />
  )
}
