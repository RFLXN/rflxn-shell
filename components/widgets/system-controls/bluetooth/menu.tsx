import { onCleanup } from "ags"
import { Gtk } from "ags/gtk4"
import Icon from "../../../icon"
import { launchSystemControlMenuProgram } from "../menu-config"
import {
  bluetoothMenuState,
  type BluetoothMenuDevice,
  type BluetoothMenuState,
} from "./menu-store"

function clearBox(box: Gtk.Box) {
  let child = box.get_first_child()

  while (child) {
    const next = child.get_next_sibling()

    box.remove(child)
    child = next
  }
}

function getConnectedDeviceCountLabel(count: number) {
  return count === 1 ? "1 connected device" : `${count} connected devices`
}

function getStatusLabel(state: BluetoothMenuState) {
  if (!state.hasAdapter) return "No adapter"
  if (!state.isPowered) return "Off"

  return "On"
}

function getStatusDescription(state: BluetoothMenuState) {
  if (!state.hasAdapter) {
    return "No Bluetooth adapter detected"
  }

  if (!state.isPowered) {
    return "Bluetooth is powered off"
  }

  return getConnectedDeviceCountLabel(state.connectedDevices.length)
}

function getStatusIconName(state: BluetoothMenuState) {
  if (!state.hasAdapter || !state.isPowered) {
    return "bluetooth_disabled"
  }

  if (state.isConnected) {
    return "bluetooth_connected"
  }

  return "bluetooth"
}

function getDeviceTags(device: BluetoothMenuDevice) {
  const tags = [device.connecting ? "Connecting" : "Connected"]

  if (device.batteryPercent !== null) {
    tags.push(`${device.batteryPercent}% battery`)
  }

  if (device.paired) {
    tags.push("Paired")
  }

  if (device.trusted) {
    tags.push("Trusted")
  }

  if (device.blocked) {
    tags.push("Blocked")
  }

  if (device.rssi !== null) {
    tags.push(`${device.rssi} dBm`)
  }

  return tags
}

function BluetoothStatus({ state }: { state: BluetoothMenuState }) {
  return (
    <box
      class="widget-system-controls-bluetooth-menu-status"
      orientation={Gtk.Orientation.HORIZONTAL}
      spacing={10}
      hexpand
    >
      <button
        class="widget-system-controls-bluetooth-menu-status-icon-container"
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
                name={getStatusIconName(state)}
                class="widget-system-controls-bluetooth-menu-status-icon"
                size={20}
              />
            ) as Gtk.Widget}
          />
        ) as Gtk.Widget}
        $={(self) => {
          self.connect("clicked", () => {
            launchSystemControlMenuProgram("bluetooth")
          })
        }}
      />
      <box
        class="widget-system-controls-bluetooth-menu-status-copy"
        orientation={Gtk.Orientation.VERTICAL}
        hexpand
        valign={Gtk.Align.CENTER}
      >
        <label
          class="widget-system-controls-bluetooth-menu-status-title text"
          label={`Bluetooth ${getStatusLabel(state)}`}
          xalign={0}
        />
        <label
          class="widget-system-controls-bluetooth-menu-status-description text"
          label={getStatusDescription(state)}
          xalign={0}
        />
      </box>
    </box>
  )
}

function BluetoothDeviceRow({ device }: { device: BluetoothMenuDevice }) {
  return (
    <box
      class={device.connecting
        ? "widget-system-controls-bluetooth-menu-device is-connecting"
        : "widget-system-controls-bluetooth-menu-device"}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={6}
      hexpand
    >
      <box
        class="widget-system-controls-bluetooth-menu-device-header"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={8}
        hexpand
      >
        <box
          class={device.connecting
            ? "widget-system-controls-bluetooth-menu-device-state is-connecting"
            : "widget-system-controls-bluetooth-menu-device-state is-connected"}
          widthRequest={10}
          heightRequest={10}
          valign={Gtk.Align.CENTER}
        />
        <label
          class="widget-system-controls-bluetooth-menu-device-name text"
          label={device.name}
          xalign={0}
          hexpand
        />
      </box>
      <box
        class="widget-system-controls-bluetooth-menu-device-tags"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={5}
        hexpand
      >
        {getDeviceTags(device).map((tag) => (
          <label
            class={tag === "Blocked"
              ? "widget-system-controls-bluetooth-menu-device-tag is-blocked text"
              : "widget-system-controls-bluetooth-menu-device-tag text"}
            label={tag}
          />
        ))}
      </box>
    </box>
  )
}

function BluetoothDeviceSection({ state }: { state: BluetoothMenuState }) {
  const section = (
    <box
      class="widget-system-controls-bluetooth-menu-section"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={4}
      hexpand
    >
      <label
        class="widget-system-controls-bluetooth-menu-section-title text"
        label="Connected devices"
        xalign={0}
      />
    </box>
  ) as Gtk.Box

  if (!state.hasAdapter || !state.isPowered) {
    section.append(
      (
        <label
          class="widget-system-controls-bluetooth-menu-empty text"
          label={state.hasAdapter ? "Bluetooth is off" : "No adapter"}
          xalign={0}
        />
      ) as Gtk.Widget,
    )
    return section
  }

  if (state.connectedDevices.length === 0) {
    section.append(
      (
        <label
          class="widget-system-controls-bluetooth-menu-empty text"
          label="No connected devices"
          xalign={0}
        />
      ) as Gtk.Widget,
    )
    return section
  }

  for (const device of state.connectedDevices) {
    section.append((<BluetoothDeviceRow device={device} />) as Gtk.Widget)
  }

  return section
}

export default function BluetoothMenu() {
  return (
    <box
      class="widget-system-controls-bluetooth-menu"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
      hexpand
      $={(self) => {
        const render = () => {
          const state = bluetoothMenuState.peek()

          clearBox(self)
          self.append((<BluetoothStatus state={state} />) as Gtk.Widget)
          self.append(BluetoothDeviceSection({ state }))
        }

        render()
        onCleanup(bluetoothMenuState.subscribe(render))
      }}
    />
  )
}
