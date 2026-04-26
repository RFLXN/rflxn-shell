# AGS Modules

`Last verified`: 2026-04-20

## Scope

This file indexes the actual `ags` package export surface.

## Important notes

- Upstream package version currently observed: `ags@3.1.2`.
- The docs site people call "AGS v2 docs" is [aylur.github.io/ags](https://aylur.github.io/ags/).
- Some official guide snippets still show `astal/gtk4/app`; the real package export is `ags/gtk4/app`.

## Module index

### `ags`

This is effectively a re-export of `gnim`.

Main symbols you will use most often:

| Category | Symbols |
| --- | --- |
| JSX core | `getType`, `jsx`, `appendChild`, `removeChild`, `Fragment` |
| Control flow | `For`, `With`, `This` |
| Lifecycle | `createRoot`, `getScope`, `onCleanup`, `onMount`, `createContext` |
| Reactivity | `Accessor`, `createState`, `createEffect`, `createComputed`, `createMemo`, `createBinding`, `createConnection`, `createExternal`, `createSettings` |
| Types | `Node`, `CCProps`, `FCProps`, `Context`, `Scope`, `State`, `Setter`, `Accessed` |

### `ags/gtk4`

| Export | Meaning |
| --- | --- |
| `Astal` | `gi://Astal?version=4.0` |
| `Gtk` | `gi://Gtk?version=4.0` |
| `Gdk` | `gi://Gdk?version=4.0` |

### `ags/gtk4/app`

Default export: singleton `app`.

High-value config fields for `app.start()`:

- `instanceName`
- `css`
- `icons`
- `gtkTheme`
- `iconTheme`
- `cursorTheme`
- `main(...argv)`
- `requestHandler(argv, res)`

High-value methods and properties:

- `start(config)`
- `get_monitors()` / `monitors`
- `windows`
- `get_window(name)`
- `toggle_window(name)`
- `apply_css(style, reset?)`
- `reset_css()`
- `add_icons(path)`
- `quit(code?)`
- `gtkTheme`
- `iconTheme`
- `cursorTheme`

Signals:

- `request`
- `window-toggled`

### `ags/gtk4/jsx-runtime`

Adds AGS-specific intrinsic JSX tags on top of `gnim/gtk4/jsx-runtime`.

### `ags/gtk3`

| Export | Meaning |
| --- | --- |
| `Astal` | `gi://Astal?version=3.0` |
| `Gtk` | `gi://Gtk?version=3.0` |
| `Gdk` | `gi://Gdk?version=3.0` |

### `ags/gtk3/app`

Same role as `ags/gtk4/app`, but with Gtk3 implementation details.

Public surface to care about:

- `start`
- `get_monitors` / `monitors`
- `windows`
- `get_window`
- `toggle_window`
- `apply_css`
- `reset_css`
- `add_icons`
- `quit`
- `gtkTheme`
- `iconTheme`
- `cursorTheme`
- signals: `request`, `window-toggled`

### `ags/gtk3/jsx-runtime`

Adds AGS-specific intrinsic JSX tags on top of `gnim/gtk3/jsx-runtime`.

### `ags/file`

| API | Purpose |
| --- | --- |
| `readFile` / `readFileAsync` | read file contents |
| `writeFile` / `writeFileAsync` | write file contents |
| `monitorFile` | recursively watch files/directories |

### `ags/process`

| API | Purpose |
| --- | --- |
| `Process` | subprocess wrapper class |
| `subprocess(...)` | spawn process and stream output |
| `exec(cmd)` | sync command execution |
| `execAsync(cmd)` | async command execution |
| `createSubprocess(...)` | lazy reactive subprocess accessor |

Key `Process` instance methods:

- `kill()`
- `signal(signalNumber)`
- `write(str)`
- `writeAsync(str)`

### `ags/time`

| API | Purpose |
| --- | --- |
| `Timer` | timer wrapper class |
| `interval(ms, cb?)` | recurring timer |
| `timeout(ms, cb?)` | one-shot timer |
| `idle(cb?)` | idle callback timer |
| `createPoll(...)` | lazy reactive polling accessor |

### `ags/gobject`

Re-export of `gnim/gobject`.

High-value exports:

- default `GObject`
- `Object`
- `SignalFlags`
- `AccumulatorType`
- `ParamSpec`
- `ParamFlags`
- `property()`
- `getter()`
- `setter()`
- `signal()`
- `register()`
- `gtype()`

### `ags/dbus`

Re-export of `gnim/dbus`.

High-value exports:

- `Variant`
- `Service`
- `iface()`
- `method()`
- `methodAsync()`
- `property()`
- `getter()`
- `setter()`
- `signal()`

### `ags/fetch`

Re-export of `gnim/fetch`.

High-value exports:

- default `fetch`
- `fetch()`
- `URL`
- `URLSearchParams`
- `Headers`
- `Response`

## Primary references

- [AGS home](https://aylur.github.io/ags/)
- [Quick Start](https://aylur.github.io/ags/guide/quick-start.html)
- [App and CLI](https://aylur.github.io/ags/guide/app-cli.html)
- [Utilities](https://aylur.github.io/ags/guide/utilities.html)
- [Aylur/ags upstream](https://github.com/Aylur/ags)
