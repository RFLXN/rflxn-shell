# Wayland Shell Helpers

`Last verified`: 2026-04-20

## Scope

This file covers the Wayland-specific helper namespaces that matter for a desktop shell.

## `Gtk4LayerShell`

Local type file: `@girs/gtk4layershell-1.0.d.ts`  
Import: `gi://Gtk4LayerShell?version=1.0`

Important structural note:

- this is a function-based API, not a class-based API

High-value functions:

- `is_supported()`
- `init_for_window(window)`
- `set_layer(window, layer)`
- `set_anchor(window, edge, anchor)`
- `set_margin(window, edge, size)`
- `set_exclusive_zone(window, size)`
- `auto_exclusive_zone_enable(window)`
- `set_keyboard_mode(window, mode)`
- `set_namespace(window, name)`
- `set_monitor(window, monitor)`

Use this when you are configuring a shell window directly as a layer-surface.

## `Gtk4SessionLock`

Local type file: `@girs/gtk4sessionlock-1.0.d.ts`  
Import: `gi://Gtk4SessionLock?version=1.0`

High-value API:

- `is_supported()`
- `Instance`

Important `Instance` signals:

- `failed`
- `locked`
- `monitor`
- `unlocked`

This is only relevant if you build lock-screen style behavior.

## `GdkWayland`

Local type file: `@girs/gdkwayland-4.0.d.ts`  
Import: `gi://GdkWayland?version=4.0`

Use this when you need Wayland-specific access beyond plain `Gdk`.

## Practical guidance

- If you are using AGS `Astal.Window`, start with Astal's own layer-shell abstractions.
- Drop down to `Gtk4LayerShell` when you need explicit layer-surface control.
- Keep this separate from general Gtk docs so shell/window protocol details stay easy to find.

## Primary references

- [gtk4-layer-shell reference](https://wmww.github.io/gtk4-layer-shell/)
- [GTK4 Layer Shell API](https://wmww.github.io/gtk4-layer-shell/gtk4-layer-shell-GTK4-Layer-Shell.html)
