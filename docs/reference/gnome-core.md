# GNOME Core Libraries

`Last verified`: 2026-04-20

## Scope

This file covers the platform core beneath Gtk and Astal:

- GLib
- Gio
- GObject
- GModule
- GIRepository
- Unix-specific companion namespaces

## GLib

Local type file: `@girs/glib-2.0.d.ts`  
Import: `gi://GLib?version=2.0`

High-value areas:

- environment and paths: `getenv`, `path_*`
- main loop and source helpers
- `DateTime`
- `Bytes`
- `Variant`
- `KeyFile`

Important note:

- the local type file includes advanced TypeScript `Variant` inference helpers
- those helpers are TS ergonomics, not extra runtime API

## Gio

Local type file: `@girs/gio-2.0.d.ts`  
Import: `gi://Gio?version=2.0`

High-value areas for shell work:

- `File`
- `FileMonitor`
- `Subprocess`
- `Settings`
- `DBusProxy`
- `DBusConnection`
- `Application`
- `SimpleAction`
- `ListModel`

If you need file IO, DBus, subprocesses, or settings, this is the main namespace.

## GObject

Local type file: `@girs/gobject-2.0.d.ts`  
Import: `gi://GObject?version=2.0`

High-value areas:

- `Object`
- signal system
- property system
- `ParamSpec`
- enum and flags helpers

In day-to-day AGS code, you usually touch this through decorators or GI classes rather than raw helper functions.

## GModule

Local type file: `@girs/gmodule-2.0.d.ts`  
Import: `gi://GModule?version=2.0`

Mostly relevant for lower-level dynamic module behavior.

## GIRepository

Local type files:

- `@girs/girepository-2.0.d.ts`
- `@girs/girepository-3.0.d.ts`

Imports:

- `gi://GIRepository?version=2.0`
- `gi://GIRepository?version=3.0`

Use when working with typelib/introspection metadata itself.

## Unix-specific companions

| Namespace | Local type file | Import | Use |
| --- | --- | --- | --- |
| `GLibUnix` | `@girs/glibunix-2.0.d.ts` | `gi://GLibUnix?version=2.0` | unix-specific GLib helpers |
| `GioUnix` | `@girs/giounix-2.0.d.ts` | `gi://GioUnix?version=2.0` | unix-specific Gio helpers |

## Primary references

- [GLib](https://docs.gtk.org/glib/)
- [GObject](https://docs.gtk.org/gobject/)
- [GIO](https://docs.gtk.org/gio/)
- [GTK Documentation](https://docs.gtk.org/)
