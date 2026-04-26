# GJS Runtime

`Last verified`: 2026-04-20

## Scope

This file covers the non-GIR runtime parts of the local type surface:

- `system`
- `console`
- `gettext`
- `cairo`
- GJS ambient/module support files like `gjs.d.ts`, `gi.d.ts`, `dom.d.ts`

## Builtin modules

### `system`

Local type file: `@girs/system.d.ts`

Import:

```ts
import System from "system"
```

High-value APIs:

- `programInvocationName`
- `programPath`
- `programArgs`
- `exit(code)`
- `gc()`
- `breakpoint()`
- `addressOf()`
- `addressOfGObject()`
- `refcount()`

Use this for low-level process/runtime behavior in plain GJS.

### `console`

Local type file: `@girs/console.d.ts`

Import:

```ts
import Console from "console"
```

High-value APIs:

- `setConsoleLogDomain()`
- `getConsoleLogDomain()`
- `DEFAULT_LOG_DOMAIN`

Relevant here because AGS uses log domains per instance.

### `gettext`

Local type file: `@girs/gettext.d.ts`

Import:

```ts
import Gettext from "gettext"
```

High-value APIs:

- `setlocale()`
- `textdomain()`
- `bindtextdomain()`
- `gettext()`
- `ngettext()`
- `pgettext()`
- `domain()`

### `cairo`

Local type files:

- `@girs/cairo.d.ts`
- `@girs/cairo-1.0.d.ts`

Import:

```ts
import Cairo from "cairo"
```

Use when you need low-level drawing, usually from `Gtk.DrawingArea`.

## Ambient support files

### `@girs/gjs.d.ts`

This provides typing for the broader GJS environment and package helpers.

### `@girs/gi.d.ts`

This underpins `gi://...` import typing.

### `@girs/dom.d.ts`

This provides web-like global typings exposed in the TS environment.

Examples:

- `TextEncoder`
- `TextDecoder`
- timers API types

## Import patterns

### GI libraries

```ts
import GLib from "gi://GLib?version=2.0"
import Gio from "gi://Gio?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
```

### GJS builtins

```ts
import System from "system"
import Gettext from "gettext"
import Cairo from "cairo"
```

### AGS wrappers

```ts
import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
```

## Practical notes

- For runtime behavior, prefer [gjs.guide](https://gjs.guide/).
- For exact builtin module typings, trust local `@girs`.
- `system`, `console`, and `gettext` are not normal GIR namespaces, so `docs.gtk.org` is not the main reference for them.

## Primary references

- [gjs.guide](https://gjs.guide/)
- [GJS Intro](https://gjs.guide/guides/gjs/intro.html)
- [GNOME JavaScript Docs](https://gjs-docs.gnome.org/)
