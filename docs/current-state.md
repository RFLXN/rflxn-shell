# Current State

Last updated: 2026-04-24

## Summary

This repository is no longer an empty AGS scaffold. It contains a mostly
implemented Hyprland GUI shell built with AGS, GJS, Gtk4, Astal, and
Gtk4LayerShell.

The current shell is centered around a compact top bar, left/right overlay
drawers, a bottom app launcher, and a full-screen confirmation overlay for
session/power actions.

## Entry Point

- `app.tsx` starts the AGS Gtk4 app.
- It loads `style.scss`, registers `handleIpcRequest`, renders `Layout`, and
  recursively adds every `Gtk.Window` found in the JSX tree to the AGS app.
- `app.gtkTheme` is currently set to `Adwaita`.

## Layout

`layout.tsx` parses the root-level `layout.json` and renders layout
definitions from that JSON file.

Each layout entry uses this shape:

```json
{
  "monitor": "DP-3",
  "widgets": {
    "left": [],
    "center": ["workspaces"],
    "right": []
  },
  "components": ["app-launcher-menu"]
}
```

The default JSON config declares two monitor connectors:

- Primary layout: `DP-3`
- Sub layout: `HDMI-A-1`

If a connector is not found through `app.get_monitors()`, that layout returns no
windows and logs the missing monitor.

### Primary Layout

The primary JSON entry creates:

- Top bar
- App launcher overlay menu
- Feed hub overlay menu
- System controls overlay menu
- Shutdown confirmation overlay
- Global menu close layers for the other monitors

Primary bar placement:

- Left: feed hub widget, focused window title
- Center: monitor-filtered Hyprland workspaces, date/time
- Right: system controls

### Sub Layout

The secondary JSON entry creates a top bar for the secondary monitor.

Sub bar placement:

- Left: date/time
- Center: monitor-filtered Hyprland workspaces
- Right: hardware monitor

## Design System

The visual style is a compact dark desktop shell UI.

- Theme tokens live in `styles/theme.scss`.
- `style.scss` imports the theme, bar, global menu, shutdown overlay, and widget
  styles.
- The base text class uses the `Pretendard` font.
- The dominant surfaces are dark gray/green-tinted panels with teal accent
  states.
- Warning, critical, success, and muted states are represented by shared theme
  colors.
- Most controls use small circular or pill-shaped hit targets.

Material Symbols SVG assets are stored under `assets/icons/material/*.svg`.
`components/icon/index.tsx` renders these SVGs through a `Gtk.DrawingArea` and
Cairo mask so the icons follow the current CSS foreground color.

Application icons are resolved through `components/app-icon.tsx`, which uses a
Papirus icon theme instance and supports file-backed icon paths.

## Implemented Features

### Bar

`components/bar/index.tsx` creates a top `Astal.Window` with
`Astal.Layer.TOP` and exclusive layer-shell behavior.

The bar measures its rail height and writes the exclusive zone through
`Gtk4LayerShell.set_exclusive_zone()`. The value is also stored in
`components/bar/store.ts` so overlay menus can offset themselves below the bar.

`components/bar/BarSkirt.tsx` draws the curved bottom skirt on both sides of
the bar with Cairo.

### Global Menu State

`components/global-store.tsx` controls:

- Which global menu is mounted
- Which global menu is revealed
- App launcher visibility/reveal state
- Shutdown confirmation state

Only one global menu or app launcher is intended to be open at a time.
`components/global-menu-close-layer.tsx` creates transparent overlay click
targets on non-primary monitors while a menu is visible.

### IPC

`ipc/index.ts` routes AGS request calls to named handlers.

Currently supported request:

```text
ags request launcher <toggle|open|close>
```

### App Launcher

The app launcher is implemented in `components/widgets/app-launcher`.

It provides:

- `AstalApps` fuzzy application search
- Default results sorted by launch frequency and name
- Keyboard navigation with arrow keys and Tab/Shift+Tab
- Enter-to-launch behavior
- Pointer-hover active row selection
- Detached application launch through `uwsm app` or `systemd-run --user`
- Bottom-centered slide-up overlay menu

### Feed Hub

The feed hub is implemented in `components/widgets/feed-hub`.

It provides:

- A bar button with notification indicator dot
- Left-side slide-in drawer
- System tray list through `AstalTray`
- Tray primary activation and secondary context menu handling
- Notification list through `AstalNotifd`
- Notification dismiss, dismiss all, and action invoke support
- Empty notification state

### Hyprland Widgets

Hyprland state is implemented in `components/widgets/hyprland` and
`utils/hyprland/workspaces.ts`.

It provides:

- Workspace snapshots
- Focused, active, occupied, and empty workspace states
- Per-workspace window icon snapshots
- Window focus by address
- Workspace focus by id
- Focused window title
- DrawingArea-based scrolling title rendering for long titles

### System Controls

System controls are implemented in `components/widgets/system-controls`.

The bar widget currently shows:

- Default speaker volume
- Battery presence indicator with placeholder percentage
- Bluetooth status
- Network status

The right-side drawer currently contains:

- Output audio device list
- Input audio device list
- Per-device volume sliders
- Per-device mute toggles
- Per-device default selection
- Footer actions for logout, restart, and power off

The footer actions open the shutdown confirmation overlay before executing the
actual action.

### Shutdown Confirmation Overlay

`components/shutdown-confirmation-overlay` implements a full-screen overlay
with a scrim and centered confirmation card.

Supported actions:

- Power off through `systemctl poweroff`
- Restart through `systemctl reboot`
- Logout through `uwsm stop`, falling back to `hyprctl dispatch exit`

### Hardware Monitor

`components/widgets/hw-monitor` and `utils/hw-monitor.ts` implement direct
system polling for:

- CPU usage, average clock, average temperature, hottest temperature
- GPU usage, clock, temperature, VRAM temperature, VRAM usage
- RAM used bytes and usage percentage

Data is read from `/proc`, `/sys/class/hwmon`, `/sys/class/drm`, and
`/sys/devices/system/cpu/cpufreq`.

## Nix

`flake.nix` now exposes:

- `packages.<system>.ags-shell` and `packages.<system>.default`
- `homeManagerModules.ags-shell` and `homeManagerModules.default`
- `nixosModules.ags-shell`
- `devShells.<system>.default`

The Home Manager module is enabled with
`programs.ags-shell.enable = true`. It installs the AGS package, installs the
same runtime package set used by the devShell, packages this source tree into
the Nix store, and symlinks `~/.config/ags` to the packaged source tree.
The default runtime package set includes `papirus-icon-theme` for the
`Papirus-Dark` icon theme used by application icons.

The NixOS helper module adds the Home Manager module to
`home-manager.sharedModules`, so system configs can set
`home-manager.users.<username>.programs.ags-shell.enable = true`.

`programs.ags-shell.layout` can override the root `layout.json` value from Nix.
The generated layout JSON is placed at the package root before the config
symlink is created.

## Known Gaps

- Monitor connectors are currently configured in `layout.json` or
  `programs.ags-shell.layout`.
- Battery display currently only hides/shows based on battery presence; the
  displayed percentage is still a placeholder default from `BatteryControl`.
- `components/widgets/test/index.tsx` is a hardcoded local test widget and is
  not wired into the current layout.
- Full TypeScript checking is currently blocked by an external AGS/Gnim source
  diagnostic; see `docs/known-issue.md`.
