# GTK UI Stack

`Last verified`: 2026-04-20

## Scope

This file covers the UI-side namespaces you are likely to touch while writing shell components.

## Core UI namespaces

| Namespace | Local type file | Import | Main role |
| --- | --- | --- | --- |
| `Gtk` | `@girs/gtk-4.0.d.ts` | `gi://Gtk?version=4.0` | widgets and application UI |
| `Gdk` | `@girs/gdk-4.0.d.ts` | `gi://Gdk?version=4.0` | displays, monitors, input, surfaces |
| `Adw` | `@girs/adw-1.d.ts` | `gi://Adw?version=1` | libadwaita widgets and app helpers |
| `Soup` | `@girs/soup-3.0.d.ts` | `gi://Soup?version=3.0` | HTTP and websocket |

## Text and rendering support

| Namespace | Local type file | Import | Main role |
| --- | --- | --- | --- |
| `Pango` | `@girs/pango-1.0.d.ts` | `gi://Pango?version=1.0` | text layout |
| `PangoCairo` | `@girs/pangocairo-1.0.d.ts` | `gi://PangoCairo?version=1.0` | cairo-backed text rendering |
| `GdkPixbuf` | `@girs/gdkpixbuf-2.0.d.ts` | `gi://GdkPixbuf?version=2.0` | image loading |
| `Gsk` | `@girs/gsk-4.0.d.ts` | `gi://Gsk?version=4.0` | render scene graph |
| `Graphene` | `@girs/graphene-1.0.d.ts` | `gi://Graphene?version=1.0` | math primitives |

## What matters most for this repo

### `Gtk`

High-value widget families:

- `Application`
- `Window`
- `Box`
- `CenterBox`
- `Overlay`
- `Revealer`
- `Label`
- `Image`
- `Button`
- `MenuButton`
- `Popover`
- `ScrolledWindow`
- `Stack`
- `EventControllerKey`
- `GestureClick`

### `Gdk`

High-value areas:

- `Display`
- `Monitor`
- key values and input events
- clipboard and surface interaction

For a multi-monitor shell, `Gdk.Display` and `Gdk.Monitor` show up constantly.

### `Adw`

High-value classes if you decide to blend libadwaita into shell tooling or settings UI:

- `Application`
- `ApplicationWindow`
- `Window`
- `Clamp`
- `ActionRow`
- dialog and preferences widgets

### `Pango`

Use this mostly for:

- `EllipsizeMode`
- `WrapMode`
- layout and text shaping concepts

In AGS code you usually see it through label properties such as ellipsize and wrapping behavior.

### `Soup`

Use this when raw `ags/fetch` is not enough and you need lower-level HTTP or websocket control.

## Primary references

- [Gtk 4](https://docs.gtk.org/gtk4/)
- [Gdk 4](https://docs.gtk.org/gdk4/)
- [Pango](https://docs.gtk.org/Pango/)
- [Adw 1](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/)
- [GTK Documentation](https://docs.gtk.org/)
