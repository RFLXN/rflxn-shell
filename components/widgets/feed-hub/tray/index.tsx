import { For, onCleanup } from "ags"
import type AstalTray from "gi://AstalTray?version=0.1"
import { Gtk } from "ags/gtk4"
import { trayItems } from "./store"

const TRAY_ITEM_SIZE = 26
const TRAY_ICON_SIZE = 18

const TRAY_ITEM_REFRESH_SIGNALS = [
  "changed",
  "ready",
  "notify::gicon",
  "notify::icon-name",
  "notify::icon-pixbuf",
  "notify::icon-theme-path",
  "notify::menu-model",
  "notify::action-group",
  "notify::tooltip-text",
  "notify::title",
] as const

function toText(value: string | null | undefined) {
  return typeof value === "string" ? value.trim() : ""
}

function getTrayItemTooltip(item: AstalTray.TrayItem) {
  return (
    toText(item.get_tooltip_text()) ||
    toText(item.get_title()) ||
    toText(item.get_id())
  )
}

function getTrayItemIconName(item: AstalTray.TrayItem) {
  try {
    return toText(item.get_icon_name())
  } catch {
    return ""
  }
}

function syncTrayIcon(image: Gtk.Image, item: AstalTray.TrayItem) {
  const gicon = item.get_gicon()
  const iconName = getTrayItemIconName(item)

  if (gicon) {
    image.set_from_gicon(gicon)
  } else if (iconName) {
    image.set_from_icon_name(iconName)
  } else {
    image.set_from_icon_name("image-missing-symbolic")
  }

  image.set_pixel_size(TRAY_ICON_SIZE)
  image.set_visible(true)
  image.set_tooltip_text(getTrayItemTooltip(item) || null)
}

function openTrayContextMenu(
  anchor: Gtk.Widget,
  item: AstalTray.TrayItem,
  getPopover: () => Gtk.PopoverMenu,
  x: number,
  y: number,
) {
  const menuModel = item.get_menu_model()
  const actionGroup = item.get_action_group()

  if (!menuModel || !actionGroup) {
    item.secondary_activate(Math.round(x), Math.round(y))
    return
  }

  const popover = getPopover()

  item.about_to_show()
  anchor.insert_action_group("dbusmenu", actionGroup)
  popover.set_menu_model(menuModel)
  popover.popup()
}

function addSecondaryClick(
  widget: Gtk.Widget,
  onClick: (x: number, y: number) => void,
) {
  const click = Gtk.GestureClick.new()

  click.set_button(3)
  click.connect("pressed", (gesture, nPress, x, y) => {
    if (nPress !== 1) return

    gesture.set_state(Gtk.EventSequenceState.CLAIMED)
    onClick(x, y)
  })

  widget.add_controller(click)
}

function addPrimaryClick(
  widget: Gtk.Widget,
  onClick: (x: number, y: number) => void,
) {
  const click = Gtk.GestureClick.new()

  click.set_button(1)
  click.connect("released", (gesture, nPress, x, y) => {
    if (nPress !== 1) return

    gesture.set_state(Gtk.EventSequenceState.CLAIMED)
    onClick(x, y)
  })

  widget.add_controller(click)
}

function activateTrayItem(
  anchor: Gtk.Widget,
  item: AstalTray.TrayItem,
  getPopover: () => Gtk.PopoverMenu,
  x: number,
  y: number,
) {
  if (item.get_is_menu()) {
    openTrayContextMenu(anchor, item, getPopover, x, y)
    return
  }

  item.activate(Math.round(x), Math.round(y))
}

function TrayIcon({ item }: { item: AstalTray.TrayItem }) {
  const image = Gtk.Image.new()

  image.set_css_classes(["widget-feed-hub-tray-icon"])
  image.set_halign(Gtk.Align.CENTER)
  image.set_valign(Gtk.Align.CENTER)

  return (
    <centerbox
      class="widget-feed-hub-tray-item"
      widthRequest={TRAY_ITEM_SIZE}
      heightRequest={TRAY_ITEM_SIZE}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      centerWidget={image}
      $={(self) => {
        let popover: Gtk.PopoverMenu | null = null
        const getPopover = () => {
          if (!popover) {
            popover = Gtk.PopoverMenu.new_from_model(null)
            popover.set_autohide(true)
            popover.set_has_arrow(false)
            popover.set_parent(self)
          }

          return popover
        }
        const sync = () => {
          syncTrayIcon(image, item)
          self.set_tooltip_text(getTrayItemTooltip(item) || null)
        }
        const signalIds = TRAY_ITEM_REFRESH_SIGNALS.map((signal) =>
          item.connect(signal, sync),
        )

        sync()
        addPrimaryClick(self, (x, y) =>
          activateTrayItem(self, item, getPopover, x, y),
        )
        addSecondaryClick(self, (x, y) =>
          openTrayContextMenu(self, item, getPopover, x, y),
        )

        onCleanup(() => {
          for (const id of signalIds) {
            item.disconnect(id)
          }

          self.insert_action_group("dbusmenu", null)
          popover?.unparent()
        })
      }}
    />
  )
}

export default function TrayIconList() {
  return (
    <box
      class="widget-feed-hub-systray"
      orientation={Gtk.Orientation.HORIZONTAL}
      spacing={4}
      valign={Gtk.Align.CENTER}
    >
      <For each={trayItems}>
        {(item) => <TrayIcon item={item} />}
      </For>
    </box>
  )
}
