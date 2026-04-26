# Shell API Reference Index

This directory splits the previous monolithic API notes into smaller reference files.

## Start here

Use this table as the router for "what should go where".

| If you need... | Go to |
| --- | --- |
| AGS module exports and import paths | [ags-modules.md](./ags-modules.md) |
| AGS CLI commands and built-in JSX tags | [ags-cli-and-intrinsics.md](./ags-cli-and-intrinsics.md) |
| GJS builtins like `system`, `console`, `gettext`, `cairo` | [gjs-runtime.md](./gjs-runtime.md) |
| GLib, Gio, GObject, GIRepository | [gnome-core.md](./gnome-core.md) |
| Gtk, Gdk, Pango, Adw, Soup and UI stack libraries | [gtk-ui.md](./gtk-ui.md) |
| layer-shell, session-lock, Wayland-specific helpers | [wayland-shell.md](./wayland-shell.md) |
| Astal core widgets and Astal service libraries | [astal-libraries.md](./astal-libraries.md) |
| full local namespace inventory from `@girs` | [local-inventory.md](./local-inventory.md) |

## File map

| File | Scope |
| --- | --- |
| [ags-modules.md](./ags-modules.md) | `ags/*` export surface |
| [ags-cli-and-intrinsics.md](./ags-cli-and-intrinsics.md) | AGS CLI and intrinsic JSX elements |
| [gjs-runtime.md](./gjs-runtime.md) | GJS environment, builtin modules, import patterns |
| [gnome-core.md](./gnome-core.md) | GLib, Gio, GObject and related platform core |
| [gtk-ui.md](./gtk-ui.md) | Gtk/Gdk/Pango/Adw/Soup and UI-related namespaces |
| [wayland-shell.md](./wayland-shell.md) | Gtk4LayerShell, Gtk4SessionLock, GdkWayland |
| [astal-libraries.md](./astal-libraries.md) | Astal core and shell-facing Astal libraries |
| [local-inventory.md](./local-inventory.md) | generated `@girs` inventory and compatibility namespaces |

## How to use the doc set

- For behavior and concepts, prefer official docs.
- For exact import strings, overloads, aliases, and signal names, check `@girs/*.d.ts`.
- For AGS app code, start with AGS docs, then jump to Astal and Gtk docs as needed.

## Recommended reading order for this repo

1. [ags-modules.md](./ags-modules.md)
2. [ags-cli-and-intrinsics.md](./ags-cli-and-intrinsics.md)
3. [astal-libraries.md](./astal-libraries.md)
4. [wayland-shell.md](./wayland-shell.md)
5. [gnome-core.md](./gnome-core.md)
6. [gtk-ui.md](./gtk-ui.md)
7. [local-inventory.md](./local-inventory.md)
