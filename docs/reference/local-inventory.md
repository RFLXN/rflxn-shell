# Local GIR Inventory

`Last verified`: 2026-04-20

## Counts

- total generated `.d.ts` files in `@girs`: `75`
- Astal-related files: `13`

## A. GJS runtime and ambient environment

| Type files |
| --- |
| `index.d.ts`, `gjs.d.ts`, `gi.d.ts`, `system.d.ts`, `console.d.ts`, `gettext.d.ts`, `dom.d.ts`, `cairo.d.ts`, `cairo-1.0.d.ts` |

## B. GNOME core

| Type files |
| --- |
| `glib-2.0.d.ts`, `glibunix-2.0.d.ts`, `gio-2.0.d.ts`, `giounix-2.0.d.ts`, `gobject-2.0.d.ts`, `gmodule-2.0.d.ts`, `girepository-2.0.d.ts`, `girepository-3.0.d.ts` |

## C. GTK4 UI stack

| Type files |
| --- |
| `gdk-4.0.d.ts`, `gdkpixbuf-2.0.d.ts`, `gdkpixdata-2.0.d.ts`, `gsk-4.0.d.ts`, `graphene-1.0.d.ts`, `gtk-4.0.d.ts`, `pango-1.0.d.ts`, `pangocairo-1.0.d.ts`, `pangofc-1.0.d.ts`, `pangoft2-1.0.d.ts`, `pangoot-1.0.d.ts`, `pangoxft-1.0.d.ts`, `harfbuzz-0.0.d.ts`, `freetype2-2.0.d.ts`, `adw-1.d.ts`, `soup-3.0.d.ts` |

## D. Wayland shell helpers

| Type files |
| --- |
| `gtk4layershell-1.0.d.ts`, `gtk4sessionlock-1.0.d.ts`, `gdkwayland-4.0.d.ts` |

## E. Astal

| Type files |
| --- |
| `astal-3.0.d.ts`, `astal-4.0.d.ts`, `astalapps-0.1.d.ts`, `astalbattery-0.1.d.ts`, `astalbluetooth-0.1.d.ts`, `astalhyprland-0.1.d.ts`, `astalio-0.1.d.ts`, `astalmpris-0.1.d.ts`, `astalnetwork-0.1.d.ts`, `astalnotifd-0.1.d.ts`, `astalpowerprofiles-0.1.d.ts`, `astaltray-0.1.d.ts`, `astalwp-0.1.d.ts` |

## F. Backing libraries exposed through dependencies

| Type files |
| --- |
| `nm-1.0.d.ts`, `upowerglib-1.0.d.ts`, `wp-0.5.d.ts`, `json-1.0.d.ts`, `polkit-1.0.d.ts`, `polkitagent-1.0.d.ts`, `dbus-1.0.d.ts`, `dbusglib-1.0.d.ts`, `libxml2-2.0.d.ts` |

## G. Compatibility and non-primary namespaces

| Type files |
| --- |
| `gtk-3.0.d.ts`, `gdk-3.0.d.ts`, `gtklayershell-0.1.d.ts`, `gdkx11-3.0.d.ts`, `gdkx11-4.0.d.ts`, `xlib-2.0.d.ts`, `xrandr-1.3.d.ts`, `xfixes-4.0.d.ts`, `xft-2.0.d.ts`, `atk-1.0.d.ts`, `atspi-2.0.d.ts`, `gdesktopenums-3.0.d.ts`, `gl-1.0.d.ts`, `vulkan-1.0.d.ts`, `fontconfig-2.0.d.ts`, `win32-1.0.d.ts`, `appmenuglibtranslator-24.02.d.ts` |

## Repo-specific note

These namespaces exist locally, but the current repo is primarily pointed at Gtk4:

- `tsconfig.json` uses `jsxImportSource: "ags/gtk4"`
- `app.tsx` imports `ags/gtk4/app`

That makes the Gtk4, Wayland, and Astal sections the important ones for day-to-day shell work.
