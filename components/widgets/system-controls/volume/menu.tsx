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
}

type VolumeDeviceEntry = {
  kind: VolumeMenuDeviceKind
  device: VolumeMenuDevice
  widget: Gtk.Widget
  defaultButton: Gtk.Widget
  deviceNameLabel: Gtk.Label
  muteButton: Gtk.Button
  muteIconContainer: Gtk.CenterBox
  slider: Astal.Slider
  percentLabel: Gtk.Label
  sliderSignalId: number
  syncingSlider: boolean
  isInteracting: boolean
}

type VolumeMenuSectionRenderer = {
  widget: Gtk.Box
  titleLabel: Gtk.Widget
  kind: VolumeMenuDeviceKind
  entries: Map<number, VolumeDeviceEntry>
  emptyLabel: Gtk.Widget | null
}

type VolumeStatusRenderer = {
  widget: Gtk.Widget
  iconContainer: Gtk.CenterBox
  descriptionLabel: Gtk.Label
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

function clampSliderVolume(volume: number) {
  return Math.max(0, Math.min(volume, 1))
}

function formatSliderPercent(volume: number) {
  return `${Math.round(Math.max(0, volume) * 100)}%`
}

function toCssClasses(className: string) {
  return className.split(/\s+/).filter(Boolean)
}

function setWidgetClassName(widget: Gtk.Widget, className: string) {
  widget.set_css_classes(toCssClasses(className))
}

function getDefaultButtonClassName(device: VolumeMenuDevice) {
  return device.isDefault
    ? "widget-system-controls-volume-menu-default is-default"
    : "widget-system-controls-volume-menu-default"
}

function getMuteButtonClassName(device: VolumeMenuDevice) {
  return device.muted
    ? "widget-system-controls-volume-menu-mute is-muted"
    : "widget-system-controls-volume-menu-mute"
}

function createMuteIcon(device: VolumeMenuDevice) {
  return (
    <Icon
      name={device.muted ? "volume_mute" : "volume_down"}
      class="widget-system-controls-volume-menu-mute-icon"
      size={18}
    />
  ) as Gtk.Widget
}

function createVolumeStatusIcon(device: VolumeMenuDevice | null) {
  return (
    <Icon
      name={getVolumeStatusIconName(device)}
      class="widget-system-controls-volume-menu-status-icon"
      size={20}
    />
  ) as Gtk.Widget
}

function createVolumeStatusRenderer(state: VolumeMenuState) {
  const defaultOutput = getDefaultOutputDevice(state)
  const iconContainer = (
    <centerbox
      widthRequest={34}
      heightRequest={34}
      centerWidget={createVolumeStatusIcon(defaultOutput)}
    />
  ) as Gtk.CenterBox
  const descriptionLabel = (
    <label
      class="widget-system-controls-volume-menu-status-description text"
      label={getVolumeStatusDescription(defaultOutput)}
      xalign={0}
    />
  ) as Gtk.Label
  const widget = (
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
        child={iconContainer}
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
        {descriptionLabel}
      </box>
    </box>
  ) as Gtk.Widget

  return {
    widget,
    iconContainer,
    descriptionLabel,
  }
}

function updateVolumeStatusRenderer(
  renderer: VolumeStatusRenderer,
  state: VolumeMenuState,
) {
  const defaultOutput = getDefaultOutputDevice(state)

  renderer.iconContainer.set_center_widget(createVolumeStatusIcon(defaultOutput))
  renderer.descriptionLabel.set_label(getVolumeStatusDescription(defaultOutput))
}

function createDefaultButton(
  device: VolumeMenuDevice,
) {
  const selector = (
    <box
      class={getDefaultButtonClassName(device)}
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
  selector.set_tooltip_text("Set as default device")

  return selector
}

function createMuteButton(device: VolumeMenuDevice) {
  const iconContainer = (
    <centerbox
      class="widget-system-controls-volume-menu-mute-icon-container"
      widthRequest={28}
      heightRequest={28}
      valign={Gtk.Align.CENTER}
      centerWidget={createMuteIcon(device)}
    />
  ) as Gtk.CenterBox
  const button = (
    <button
      class={getMuteButtonClassName(device)}
      widthRequest={28}
      heightRequest={28}
      valign={Gtk.Align.CENTER}
      hasFrame={false}
      focusOnClick={false}
      child={iconContainer}
    />
  ) as Gtk.Button

  button.set_tooltip_text(device.muted ? "Unmute" : "Mute")

  return { button, iconContainer }
}

function syncVolumeDeviceSlider(entry: VolumeDeviceEntry) {
  if (entry.isInteracting) return

  const sliderValue = clampSliderVolume(entry.device.volume)

  if (Math.abs(entry.slider.get_value() - sliderValue) > 0.001) {
    entry.syncingSlider = true
    entry.slider.block_signal_handler(entry.sliderSignalId)

    try {
      entry.slider.set_value(sliderValue)
    } finally {
      entry.slider.unblock_signal_handler(entry.sliderSignalId)
      entry.syncingSlider = false
    }
  }

  entry.percentLabel.set_label(`${entry.device.volumePercent}%`)
}

function beginVolumeSliderInteraction(entry: VolumeDeviceEntry) {
  entry.isInteracting = true
}

function finishVolumeSliderInteraction(entry: VolumeDeviceEntry) {
  if (!entry.isInteracting) return

  entry.isInteracting = false

  const value = entry.slider.get_value()

  entry.percentLabel.set_label(formatSliderPercent(value))
  setVolumeMenuDeviceVolume(entry.kind, entry.device.id, value)
}

function updateVolumeDeviceEntry(
  entry: VolumeDeviceEntry,
  device: VolumeMenuDevice,
) {
  entry.device = device

  setWidgetClassName(entry.defaultButton, getDefaultButtonClassName(device))
  entry.deviceNameLabel.set_label(getDeviceLabel(device))
  setWidgetClassName(entry.muteButton, getMuteButtonClassName(device))
  entry.muteButton.set_tooltip_text(device.muted ? "Unmute" : "Mute")
  entry.muteIconContainer.set_center_widget(createMuteIcon(device))
  syncVolumeDeviceSlider(entry)
}

function createVolumeDeviceEntry({
  kind,
  device,
}: {
  kind: VolumeMenuDeviceKind
  device: VolumeMenuDevice
}) {
  const defaultButton = createDefaultButton(device)
  const deviceNameLabel = (
    <label
      class="widget-system-controls-volume-menu-device-name text"
      label={getDeviceLabel(device)}
      xalign={0}
      hexpand
    />
  ) as Gtk.Label
  const { button: muteButton, iconContainer: muteIconContainer } =
    createMuteButton(device)
  const sliderValue = clampSliderVolume(device.volume)
  const percentLabel = (
    <label
      class="widget-system-controls-volume-menu-percent text"
      label={`${device.volumePercent}%`}
      widthRequest={42}
      xalign={1}
    />
  ) as Gtk.Label
  const slider = (
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
    />
  ) as Astal.Slider
  const widget = (
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
        {deviceNameLabel}
      </box>
      <box
        class="widget-system-controls-volume-menu-device-control"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={6}
        hexpand
      >
        {muteButton}
        {slider}
        {percentLabel}
      </box>
    </box>
  ) as Gtk.Widget
  const entry: VolumeDeviceEntry = {
    kind,
    device,
    widget,
    defaultButton,
    deviceNameLabel,
    muteButton,
    muteIconContainer,
    slider,
    percentLabel,
    sliderSignalId: 0,
    syncingSlider: false,
    isInteracting: false,
  }
  const defaultClick = Gtk.GestureClick.new()
  const sliderClick = Gtk.GestureClick.new()
  const sliderDrag = Gtk.GestureDrag.new()

  defaultClick.connect("released", () => {
    if (entry.device.isDefault) return

    setVolumeMenuDeviceDefault(entry.kind, entry.device.id)
  })
  defaultButton.add_controller(defaultClick)

  muteButton.connect("clicked", () => {
    setVolumeMenuDeviceMuted(
      entry.kind,
      entry.device.id,
      !entry.device.muted,
    )
  })

  entry.sliderSignalId = slider.connect("notify::value", () => {
    if (entry.syncingSlider) return

    const value = slider.get_value()

    percentLabel.set_label(formatSliderPercent(value))
    setVolumeMenuDeviceVolume(entry.kind, entry.device.id, value)
  })

  sliderClick.set_button(1)
  sliderClick.connect("pressed", () => {
    beginVolumeSliderInteraction(entry)
  })
  sliderClick.connect("released", () => {
    finishVolumeSliderInteraction(entry)
  })
  sliderClick.connect("cancel", () => {
    finishVolumeSliderInteraction(entry)
  })
  slider.add_controller(sliderClick)

  sliderDrag.set_button(1)
  sliderDrag.connect("drag-begin", () => {
    beginVolumeSliderInteraction(entry)
  })
  sliderDrag.connect("drag-end", () => {
    finishVolumeSliderInteraction(entry)
  })
  sliderDrag.connect("cancel", () => {
    finishVolumeSliderInteraction(entry)
  })
  slider.add_controller(sliderDrag)

  return entry
}

function disposeVolumeDeviceEntry(entry: VolumeDeviceEntry) {
  if (entry.sliderSignalId !== 0) {
    entry.slider.disconnect(entry.sliderSignalId)
    entry.sliderSignalId = 0
  }
}

function createEmptyLabel() {
  return (
    <label
      class="widget-system-controls-volume-menu-empty text"
      label="No devices"
      xalign={0}
    />
  ) as Gtk.Widget
}

function createVolumeMenuSection({
  title,
  kind,
}: VolumeMenuSectionConfig) {
  const titleLabel = (
    <label
      class="widget-system-controls-volume-menu-section-title text"
      label={title}
      xalign={0}
    />
  ) as Gtk.Widget
  const section = (
    <box
      class="widget-system-controls-volume-menu-section"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={4}
      hexpand
    >
      {titleLabel}
    </box>
  ) as Gtk.Box

  return {
    widget: section,
    titleLabel,
    kind,
    entries: new Map<number, VolumeDeviceEntry>(),
    emptyLabel: null,
  }
}

function removeVolumeDeviceEntry(
  section: VolumeMenuSectionRenderer,
  id: number,
) {
  const entry = section.entries.get(id)

  if (!entry) return

  disposeVolumeDeviceEntry(entry)
  section.widget.remove(entry.widget)
  section.entries.delete(id)
}

function renderVolumeMenuSection(
  section: VolumeMenuSectionRenderer,
  devices: VolumeMenuDevice[],
) {
  const nextIds = new Set(devices.map((device) => device.id))

  for (const id of Array.from(section.entries.keys())) {
    if (!nextIds.has(id)) {
      removeVolumeDeviceEntry(section, id)
    }
  }

  if (devices.length === 0) {
    if (!section.emptyLabel) {
      section.emptyLabel = createEmptyLabel()
      section.widget.append(section.emptyLabel)
    }

    return
  }

  if (section.emptyLabel) {
    section.widget.remove(section.emptyLabel)
    section.emptyLabel = null
  }

  let previous = section.titleLabel

  for (const device of devices) {
    let entry = section.entries.get(device.id)

    if (!entry) {
      entry = createVolumeDeviceEntry({
        kind: section.kind,
        device,
      })
      section.entries.set(device.id, entry)
      section.widget.insert_child_after(entry.widget, previous)
    } else {
      updateVolumeDeviceEntry(entry, device)

      if (entry.widget.get_prev_sibling() !== previous) {
        section.widget.reorder_child_after(entry.widget, previous)
      }
    }

    previous = entry.widget
  }
}

function disposeVolumeMenuSection(section: VolumeMenuSectionRenderer) {
  for (const id of Array.from(section.entries.keys())) {
    removeVolumeDeviceEntry(section, id)
  }

  if (section.emptyLabel) {
    section.widget.remove(section.emptyLabel)
    section.emptyLabel = null
  }
}

export default function VolumeMenu() {
  return (
    <box
      class="widget-system-controls-volume-menu"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
      hexpand
      $={(self) => {
        const status = createVolumeStatusRenderer(volumeMenuState.peek())
        const outputSection = createVolumeMenuSection({
          title: "Output",
          kind: "output",
        })
        const inputSection = createVolumeMenuSection({
          title: "Input",
          kind: "input",
        })

        self.append(status.widget)
        self.append(outputSection.widget)
        self.append(inputSection.widget)

        const render = () => {
          const state = volumeMenuState.peek()

          updateVolumeStatusRenderer(status, state)
          renderVolumeMenuSection(outputSection, state.outputDevices)
          renderVolumeMenuSection(inputSection, state.inputDevices)
        }

        render()
        const unsubscribe = volumeMenuState.subscribe(render)

        onCleanup(() => {
          unsubscribe()

          self.remove(status.widget)
          disposeVolumeMenuSection(outputSection)
          disposeVolumeMenuSection(inputSection)
          self.remove(outputSection.widget)
          self.remove(inputSection.widget)
        })
      }}
    />
  )
}
