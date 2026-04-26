# Astal Libraries

`Last verified`: 2026-04-20

## Scope

This file covers both:

- Astal core GTK-side types
- Astal service libraries that feed shell state

## Astal core

### `Astal`

Local type files:

- `@girs/astal-4.0.d.ts`
- `@girs/astal-3.0.d.ts`

Imports:

- `gi://Astal?version=4.0`
- `gi://Astal?version=3.0`

High-value Gtk4 symbols:

- enums: `Exclusivity`, `Layer`, `Keymode`, `WindowAnchor`
- classes: `Window`, `Slider`, `Application`

### `AstalIO`

Local type file: `@girs/astalio-0.1.d.ts`  
Import: `gi://AstalIO?version=0.1`

High-value areas:

- daemon helpers
- file helpers
- process helpers
- variable/time helpers

Relevant symbols:

- `Process`
- `Time`
- `Variable`
- `Daemon`
- `read_file*`
- `write_file*`
- `monitor_file`

## Shell-facing Astal libraries

### `AstalHyprland`

Import: `gi://AstalHyprland?version=0.1`

High-value symbols:

- `get_default()`
- `Hyprland`
- `Client`
- `Monitor`
- `Workspace`

Priority: highest for this repo.

### `AstalNotifd`

Import: `gi://AstalNotifd?version=0.1`

High-value symbols:

- `get_default()`
- `Notifd`
- `Notification`
- `Action`
- `send_notification()`

### `AstalMpris`

Import: `gi://AstalMpris?version=0.1`

High-value symbols:

- `get_default()`
- `Mpris`
- `Player`

### `AstalTray`

Import: `gi://AstalTray?version=0.1`

High-value symbols:

- `get_default()`
- `Tray`
- `TrayItem`
- `Pixmap`
- `Tooltip`

### `AstalNetwork`

Import: `gi://AstalNetwork?version=0.1`

High-value symbols:

- `get_default()`
- `Network`
- `Wifi`
- `Wired`
- `AccessPoint`

### `AstalBattery`

Import: `gi://AstalBattery?version=0.1`

High-value symbols:

- `get_default()`
- `Device`
- `UPower`

### `AstalWp`

Import: `gi://AstalWp?version=0.1`

High-value symbols:

- `get_default()`
- `Wp`
- `Audio`
- `Video`
- `Node`
- `Stream`
- `Device`
- `Endpoint`

### `AstalApps`

Import: `gi://AstalApps?version=0.1`

High-value symbols:

- `Apps`
- `Application`
- `Score`

### `AstalBluetooth`

Import: `gi://AstalBluetooth?version=0.1`

High-value symbols:

- `get_default()`
- `Bluetooth`
- `Adapter`
- `Device`

### `AstalPowerProfiles`

Import: `gi://AstalPowerProfiles?version=0.1`

High-value symbols:

- `get_default()`
- `PowerProfiles`
- `Profile`
- `Hold`

## Priority order for this repo

1. `AstalHyprland`
2. `AstalNotifd`
3. `AstalMpris`
4. `AstalTray`
5. `AstalNetwork`
6. `AstalBattery`
7. `AstalWp`
8. `AstalApps`

## Primary references

- [Astal guide](https://aylur.github.io/astal/)
- [AstalHyprland](https://aylur.github.io/libastal/hyprland/index.html)
- [AstalTray](https://aylur.github.io/libastal/tray/index.html)
- [AGS Resources](https://aylur.github.io/ags/guide/resources.html)
