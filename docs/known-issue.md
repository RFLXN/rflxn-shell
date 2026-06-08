# Known Issues

## TypeScript Check Reports Known Diagnostics

Running:

```sh
nix-shell -p typescript --run "tsc --noEmit --pretty false"
```

currently reports one external diagnostic from the AGS/Gnim package in the Nix
store:

```text
.../ags-js-lib/node_modules/gnim/dist/jsx/state.ts(715,47): error TS2556:
A spread argument must either have a tuple type or be passed to a rest parameter.
```

Project-local type mismatches have been fixed as of 2026-04-24.

`tsconfig.json` uses `skipLibCheck: true` so generated GIR declaration files are
not type-checked as library implementation code. This suppresses duplicate
identifier noise between generated Gtk3/Gtk4 and Astal3/Astal4 declaration
files while keeping those declarations available for imports and local type
checking.

`ags bundle app.tsx /tmp/new-shell-check` succeeds.

## Feed Hub Menu Pixman Warning

When opening the feed hub menu, GJS/GTK may print a warning like this:

```text
*** BUG ***
In pixman_region32_init_rect: Invalid rectangle passed
Set a breakpoint on '_pixman_log_error' to debug
```

No user-visible breakage has been observed so far.

The likely trigger is the feed hub drawer animation:

- `Gtk.RevealerTransitionType.SLIDE_RIGHT`
- `Gtk.Overflow.HIDDEN` on the rounded menu content
- `Gtk.ScrolledWindow` and its styled scrollbar inside the revealed child

During the slide transition, GTK may temporarily allocate or clip a child at a
zero or near-zero width. That can produce an invalid rectangle warning from the
lower-level pixman renderer.

If this becomes a real rendering issue later, check these mitigations first:

- Replace the slide transition with a non-sliding transition.
- Remove or relocate `Gtk.Overflow.HIDDEN` from the animated child.
- Keep scrollbar CSS sizes non-zero.
- Move rounded clipping to a non-animated inner wrapper.

## Systray Watcher Conflict With snixembed

`AstalTray` and `snixembed` both try to own the user-session DBus name
`org.kde.StatusNotifierWatcher`. Only one process can own that name at a time.

Observed behavior:

- With `snixembed` running, `AstalTray.get_default().get_items()` may return no
  tray items.
- `busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems`
  may return `as 0`, even while apps such as Vesktop expose a
  `/StatusNotifierItem` object.
- Stopping `snixembed` with `systemctl --user stop snixembed` allowed the AGS
  tray to render normally.

The suspected root cause is watcher ownership rather than icon rendering. If
`snixembed` owns the watcher, the AGS/Astal tray cannot act as the watcher.

Keep in mind that `snixembed` may still be useful for legacy XEmbed tray icons.
If those apps are needed, test `xembedsniproxy` as an alternative bridge; it is
reported to work better with a shell-provided SNI watcher in this setup.

## Network Widget State Detection Is Unstable

The system controls network widget currently depends on `AstalNetwork` state to
choose between wired, Wi-Fi, offline, and no-internet icons.

Observed behavior:

- With LAN disconnected and Wi-Fi connected, the widget may still show the
  no-Wi-Fi icon.
- With both LAN and Wi-Fi toggled during testing, stale Wi-Fi state may make the
  widget show the lowest-strength Wi-Fi icon.

The suspected cause is that `AstalNetwork.Wifi` can expose inconsistent or stale
values across `primary`, `active_access_point`, `ssid`, `internet`, `state`, and
`strength`, especially while NetworkManager/iwd is transitioning between
connections.

The current implementation intentionally uses a conservative Wi-Fi connection
check based on `wifi.enabled && DeviceState.ACTIVATED`, but the widget should be
revisited before relying on it for precise network status. If this becomes a
real UX issue, compare Astal values against `nmcli device status` and consider
using a small NetworkManager-specific helper for snapshot normalization.

## Volume Percent Label Can Lag While Dragging

The system controls volume menu preserves each device row while the user drags a
volume slider. This avoids the previous bug where a menu state refresh rebuilt
the slider widget during pointer interaction and made the drag feel as if it had
been released.

The tradeoff is that the percentage label can feel slightly behind the pointer if
it is driven by the external volume snapshot. Volume writes go through
WirePlumber/Astal asynchronously, and the menu intentionally skips state-driven
slider synchronization while `isInteracting` is true so stale snapshots cannot
overwrite the active drag position.

If this becomes a real UX issue, keep these constraints:

- Do not rebuild the slider row while the pointer is interacting with it.
- Keep source-of-truth synchronization in `syncVolumeDeviceSlider()` for normal
  state updates.
- Update the visible percentage label optimistically from the local slider value
  during `notify::value`, using `formatSliderPercent(value)`.
- If volume writes are throttled or debounced later, keep label updates immediate
  and only debounce the actual `setVolumeMenuDeviceVolume()` calls.
