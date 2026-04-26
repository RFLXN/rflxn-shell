# AGS CLI And Intrinsics

`Last verified`: 2026-04-20

## AGS CLI

| Command | Purpose | Main flags |
| --- | --- | --- |
| `ags run [file] [gjsArgs...]` | run an app or app directory | `-d/--directory`, `--define`, `-g/--gtk`, `--log-file` |
| `ags request [argv...]` | send request to running instance | `-i/--instance` |
| `ags list` | list running instances | none |
| `ags inspect` | open Gtk debugger | `-i/--instance` |
| `ags toggle [name]` | toggle window visibility | `-i/--instance` |
| `ags quit` | quit running instance | `-i/--instance` |
| `ags types [pattern]` | generate TS types from GIRs | `-v/--verbose`, `-u/--update`, `-d/--directory`, `-i/--ignore` |
| `ags bundle [entryfile] [outfile]` | bundle app into wrapper script | `-r/--root`, `-d/--define`, `--alias`, `-g/--gtk` |
| `ags init` | create starter project | `-g/--gtk`, `-f/--force`, `-d/--directory` |

Operational notes:

- `run` infers Gtk version from imports if `--gtk` is omitted.
- `run` treats a directory as an app root and looks for `app.js`, `app.ts`, `app.jsx`, or `app.tsx`.
- `request`, `toggle`, `inspect`, and `quit` use DBus to talk to the primary app instance.

## Gtk4 intrinsics

These are the lowercase tags registered by `ags/gtk4/jsx-runtime`.

| Tag | Backing type |
| --- | --- |
| `box` | `Gtk.Box` |
| `button` | `Gtk.Button` |
| `centerbox` | `Gtk.CenterBox` |
| `drawingarea` | `Gtk.DrawingArea` |
| `entry` | `Gtk.Entry` |
| `image` | `Gtk.Image` |
| `label` | `Gtk.Label` |
| `levelbar` | `Gtk.LevelBar` |
| `menubutton` | `Gtk.MenuButton` |
| `overlay` | `Gtk.Overlay` |
| `popover` | `Gtk.Popover` |
| `revealer` | `Gtk.Revealer` |
| `scrolledwindow` | `Gtk.ScrolledWindow` |
| `slider` | `Astal.Slider` |
| `stack` | `Gtk.Stack` |
| `switch` | `Gtk.Switch` |
| `togglebutton` | `Gtk.ToggleButton` |
| `window` | `Astal.Window` |

Important note:

- Gtk4 `window` is invisible by default, so pass `visible`.

## Gtk3 intrinsics

These are the lowercase tags registered by `ags/gtk3/jsx-runtime`.

| Tag | Backing type |
| --- | --- |
| `box` | `Astal.Box` |
| `button` | `Astal.Button` |
| `centerbox` | `Astal.CenterBox` |
| `circularprogress` | `Astal.CircularProgress` |
| `drawingarea` | `Gtk.DrawingArea` |
| `entry` | `Gtk.Entry` |
| `eventbox` | `Astal.EventBox` |
| `icon` | `Astal.Icon` |
| `label` | `Astal.Label` |
| `levelbar` | `Astal.LevelBar` |
| `menubutton` | `Gtk.MenuButton` |
| `overlay` | `Astal.Overlay` |
| `popover` | `Gtk.Popover` |
| `revealer` | `Gtk.Revealer` |
| `scrollable` | `Astal.Scrollable` |
| `slider` | `Astal.Slider` |
| `stack` | `Astal.Stack` |
| `switch` | `Gtk.Switch` |
| `togglebutton` | `Gtk.ToggleButton` |
| `window` | `Astal.Window` |

## Repo note

This repository currently targets Gtk4:

- `tsconfig.json` uses `jsxImportSource: "ags/gtk4"`
- `app.tsx` currently imports `ags/gtk4/app`

So Gtk4 intrinsics are the ones to care about first.

## Primary references

- [Builtin Intrinsic Elements](https://aylur.github.io/ags/guide/intrinsics.html)
- [App and CLI](https://aylur.github.io/ags/guide/app-cli.html)
- [Aylur/ags upstream](https://github.com/Aylur/ags)
