import { onCleanup } from "ags"
import AstalApps from "gi://AstalApps?version=0.1"
import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib?version=2.0"
import Pango from "gi://Pango?version=1.0"
import { Gtk } from "ags/gtk4"
import AppIcon from "../../app-icon"
import Icon from "../../icon"
import { isAppLauncherRevealed } from "../../global-store"
import {
  appLauncherActiveIndex,
  appLauncherResults,
  clearAppLauncherQuery,
  launchActiveAppLauncherResult,
  launchAppLauncherApplication,
  moveAppLauncherActiveIndex,
  setAppLauncherActiveIndex,
  setAppLauncherQuery,
} from "./store"

type AppLauncherApplicationButtonProps = {
  app: AstalApps.Application
  index: number
  pointerHoverState: PointerHoverState
}

const ACTIVE_ROW_SCROLL_MARGIN = 8
const POINTER_MOVE_THRESHOLD = 0.5

type PointerHoverState = {
  root: Gtk.Widget | null
  suppressed: boolean
  x: number | null
  y: number | null
}

function clearBox(box: Gtk.Box) {
  let child = box.get_first_child()

  while (child) {
    const next = child.get_next_sibling()

    box.remove(child)
    child = next
  }
}

function normalizeText(value: string | null | undefined) {
  return value?.trim() ?? ""
}

function syncActiveRowClass(rows: Gtk.Widget[]) {
  const activeIndex = appLauncherActiveIndex.peek()

  rows.forEach((row, index) => {
    if (index === activeIndex) {
      row.add_css_class("is-active")
      return
    }

    row.remove_css_class("is-active")
  })
}

function createPointerHoverState(): PointerHoverState {
  return {
    root: null,
    suppressed: false,
    x: null,
    y: null,
  }
}

function suppressPointerHover(state: PointerHoverState) {
  state.suppressed = true
}

function shouldActivatePointerHover(
  state: PointerHoverState,
  row: Gtk.Widget,
  x: number,
  y: number,
) {
  let rootX = x
  let rootY = y

  if (state.root) {
    const [hasRootCoordinates, translatedX, translatedY] =
      row.translate_coordinates(state.root, x, y)

    if (hasRootCoordinates) {
      rootX = translatedX
      rootY = translatedY
    }
  }

  const moved =
    state.x === null ||
    state.y === null ||
    Math.abs(rootX - state.x) > POINTER_MOVE_THRESHOLD ||
    Math.abs(rootY - state.y) > POINTER_MOVE_THRESHOLD

  state.x = rootX
  state.y = rootY

  if (!state.suppressed) return true

  if (!moved) return false

  state.suppressed = false
  return true
}

function hasCommandModifier(modifierState: Gdk.ModifierType) {
  return Boolean(
    modifierState &
      (Gdk.ModifierType.CONTROL_MASK |
        Gdk.ModifierType.ALT_MASK |
        Gdk.ModifierType.SUPER_MASK |
        Gdk.ModifierType.META_MASK),
  )
}

function insertFallbackText(entry: Gtk.Entry, keyval: number) {
  if (keyval === Gdk.KEY_BackSpace) {
    const text = entry.get_text()
    const nextText = Array.from(text).slice(0, -1).join("")

    entry.set_text(nextText)
    entry.set_position(-1)
    return true
  }

  const unicode = Gdk.keyval_to_unicode(keyval)

  if (unicode === 0) return false

  const character = String.fromCodePoint(unicode)

  if (!character || /\p{C}/u.test(character)) return false

  entry.set_text(`${entry.get_text()}${character}`)
  entry.set_position(-1)
  return true
}

function addAppLauncherKeyController(
  widget: Gtk.Widget,
  getSearchEntry: () => Gtk.Entry | null,
  pointerHoverState: PointerHoverState,
) {
  const keyController = Gtk.EventControllerKey.new()

  keyController.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
  keyController.connect("key-pressed", (controller, keyval, _keycode, state) => {
    const isShiftTab =
      keyval === Gdk.KEY_ISO_Left_Tab ||
      (keyval === Gdk.KEY_Tab && Boolean(state & Gdk.ModifierType.SHIFT_MASK))

    if (keyval === Gdk.KEY_Down || keyval === Gdk.KEY_Tab) {
      suppressPointerHover(pointerHoverState)
      moveAppLauncherActiveIndex(isShiftTab ? -1 : 1)
      return true
    }

    if (keyval === Gdk.KEY_Up || isShiftTab) {
      suppressPointerHover(pointerHoverState)
      moveAppLauncherActiveIndex(-1)
      return true
    }

    if (keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter) {
      launchActiveAppLauncherResult()
      return true
    }

    const searchEntry = getSearchEntry()

    if (!searchEntry || searchEntry.hasFocus || hasCommandModifier(state)) {
      return false
    }

    searchEntry.grab_focus()

    if (controller.forward(searchEntry)) {
      return true
    }

    return insertFallbackText(searchEntry, keyval)
  })

  widget.add_controller(keyController)
}

function findParentScrolledWindow(widget: Gtk.Widget) {
  let parent = widget.get_parent()

  while (parent) {
    if (parent instanceof Gtk.ScrolledWindow) {
      return parent
    }

    parent = parent.get_parent()
  }

  return null
}

function scrollActiveRowIntoView(rows: Gtk.Widget[], container: Gtk.Widget) {
  const row = rows[appLauncherActiveIndex.peek()]
  const scrolledWindow = findParentScrolledWindow(container)
  const adjustment = scrolledWindow?.get_vadjustment()

  if (!row || !adjustment) return

  const [hasBounds, bounds] = row.compute_bounds(container)

  if (!hasBounds) return

  const rowTop = bounds.get_y()
  const rowBottom = rowTop + bounds.get_height()
  const viewTop = adjustment.get_value()
  const viewBottom = viewTop + adjustment.get_page_size()
  const minValue = adjustment.get_lower()
  const maxValue = adjustment.get_upper() - adjustment.get_page_size()
  let nextValue = viewTop

  if (rowTop < viewTop + ACTIVE_ROW_SCROLL_MARGIN) {
    nextValue = rowTop - ACTIVE_ROW_SCROLL_MARGIN
  } else if (rowBottom > viewBottom - ACTIVE_ROW_SCROLL_MARGIN) {
    nextValue = rowBottom - adjustment.get_page_size() + ACTIVE_ROW_SCROLL_MARGIN
  }

  adjustment.set_value(Math.max(minValue, Math.min(nextValue, maxValue)))
}

function queueScrollActiveRowIntoView(rows: Gtk.Widget[], container: Gtk.Widget) {
  GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
    scrollActiveRowIntoView(rows, container)
    return GLib.SOURCE_REMOVE
  })
}

function AppLauncherApplicationButton({
  app,
  index,
  pointerHoverState,
}: AppLauncherApplicationButtonProps) {
  const name =
    normalizeText(app.get_name()) ||
    normalizeText(app.get_entry()) ||
    "Unknown Application"
  const icon =
    AppIcon({
      name: app.get_icon_name(),
      class: "widget-app-launcher-application-icon",
      size: 34,
    }) ??
    (Icon({
      name: "web_asset",
      class: "widget-app-launcher-application-icon text",
      size: 30,
    }) as Gtk.Widget)
  const description = normalizeText(app.get_description())

  return (
    <button
      class="widget-app-launcher-application-button"
      hasFrame={false}
      focusOnClick={false}
      hexpand
      $={(self) => {
        const motion = Gtk.EventControllerMotion.new()

        motion.connect("motion", (_controller, x, y) => {
          if (!shouldActivatePointerHover(pointerHoverState, self, x, y)) {
            return
          }

          setAppLauncherActiveIndex(index)
        })
        self.add_controller(motion)
        self.connect("notify::has-focus", () => {
          if (self.hasFocus) setAppLauncherActiveIndex(index)
        })
        self.connect("clicked", () => launchAppLauncherApplication(app))
        self.set_cursor_from_name("pointer")
      }}
    >
      <box
        class="widget-app-launcher-application"
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={12}
        hexpand
      >
        <centerbox
          class="widget-app-launcher-application-icon-box"
          widthRequest={48}
          heightRequest={48}
          centerWidget={icon}
        />
        <box
          class="widget-app-launcher-application-labels"
          orientation={Gtk.Orientation.VERTICAL}
          valign={Gtk.Align.CENTER}
          hexpand
        >
          <label
            class="widget-app-launcher-application-name"
            label={name}
            xalign={0}
            ellipsize={Pango.EllipsizeMode.END}
            maxWidthChars={42}
            hexpand
          />
          {description ? (
            <label
              class="widget-app-launcher-application-description"
              label={description}
              xalign={0}
              ellipsize={Pango.EllipsizeMode.END}
              maxWidthChars={48}
              hexpand
            />
          ) : null}
        </box>
      </box>
    </button>
  )
}

function AppLauncherResults({
  pointerHoverState,
}: {
  pointerHoverState: PointerHoverState
}) {
  return (
    <box
      class="widget-app-launcher-results"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={4}
      hexpand
      $={(self) => {
        let rows: Gtk.Widget[] = []
        const syncActiveRow = () => {
          syncActiveRowClass(rows)
          queueScrollActiveRowIntoView(rows, self)
        }

        const renderResults = () => {
          const results = appLauncherResults.peek()

          rows = []
          clearBox(self)

          if (results.length === 0) {
            self.append(
              (
                <box
                  class="widget-app-launcher-empty"
                  orientation={Gtk.Orientation.VERTICAL}
                  hexpand
                  vexpand
                >
                  <label
                    class="widget-app-launcher-empty-title"
                    label="No applications found"
                  />
                </box>
              ) as Gtk.Widget,
            )
            return
          }

          results.forEach((app, index) => {
            const row = (
              <AppLauncherApplicationButton
                app={app}
                index={index}
                pointerHoverState={pointerHoverState}
              />
            ) as Gtk.Widget

            rows.push(row)
            self.append(row)
          })
          syncActiveRow()
        }

        renderResults()
        onCleanup(appLauncherResults.subscribe(renderResults))
        onCleanup(appLauncherActiveIndex.subscribe(syncActiveRow))
      }}
    />
  )
}

export default function AppLauncher() {
  const pointerHoverState = createPointerHoverState()
  let searchEntry: Gtk.Entry | null = null

  return (
    <box
      class="widget-app-launcher"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
      hexpand
      vexpand
      $={(self) => {
        pointerHoverState.root = self
        addAppLauncherKeyController(self, () => searchEntry, pointerHoverState)
      }}
    >
      <entry
        class="widget-app-launcher-search"
        placeholderText="Search applications"
        hexpand
        $={(self) => {
          searchEntry = self
          self.connect("notify::text", () => {
            setAppLauncherQuery(self.get_text())
          })
          self.connect("activate", () => {
            launchActiveAppLauncherResult()
          })

          const focusSearch = (revealed: boolean) => {
            if (!revealed) return

            GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
              clearAppLauncherQuery()
              self.set_text("")
              self.grab_focus()
              return GLib.SOURCE_REMOVE
            })
          }

          focusSearch(isAppLauncherRevealed.peek())
          onCleanup(
            isAppLauncherRevealed.subscribe(() => {
              focusSearch(isAppLauncherRevealed.peek())
            }),
          )
        }}
      />
      <scrolledwindow
        class="widget-app-launcher-scroll"
        hscrollbarPolicy={Gtk.PolicyType.NEVER}
        vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
        hexpand
        vexpand
      >
        <AppLauncherResults pointerHoverState={pointerHoverState} />
      </scrolledwindow>
    </box>
  )
}
