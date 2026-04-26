import GLib from "gi://GLib?version=2.0"
import { Gtk } from "ags/gtk4"

type AppIconProps = {
  class?: string
  name?: string | null
  size?: number | "css"
}

const PAPIRUS_THEME_NAME = "Papirus-Dark"

let papirusTheme: Gtk.IconTheme | null = null

function getPapirusTheme() {
  if (!papirusTheme) {
    papirusTheme = Gtk.IconTheme.new()
    papirusTheme.set_theme_name(PAPIRUS_THEME_NAME)
  }

  return papirusTheme
}

function isFileIcon(name: string) {
  return name.startsWith("/")
}

function toCssClasses(className?: string) {
  return className?.split(/\s+/).filter(Boolean) ?? []
}

function measureCssSize(widget: Gtk.Widget) {
  const width = widget.measure(Gtk.Orientation.HORIZONTAL, -1)[0]
  const height = widget.measure(Gtk.Orientation.VERTICAL, -1)[0]
  const size = Math.min(width, height)

  return size > 0 ? size : null
}

function queueCssSizeUpdate(update: () => void) {
  setTimeout(update)
}

function trackCssIconSize(widget: Gtk.Widget, update: (size: number) => void) {
  let currentSize = 0
  const syncSize = () => {
    const size = measureCssSize(widget)

    if (!size || size === currentSize) return

    currentSize = size
    update(size)
  }

  const queueUpdate = () => queueCssSizeUpdate(syncSize)

  queueUpdate()
  widget.connect("map", queueUpdate)
  widget.connect("notify::root", queueUpdate)
  widget.connect("notify::css-classes", queueUpdate)
}

function lookupPapirusIcon(iconName: string, size: number) {
  return getPapirusTheme().lookup_icon(
    iconName,
    null,
    size,
    1,
    Gtk.TextDirection.NONE,
    Gtk.IconLookupFlags.FORCE_REGULAR,
  )
}

function fileExists(path: string) {
  return GLib.file_test(path, GLib.FileTest.EXISTS)
}

export default function AppIcon({
  name,
  class: className,
  size = 18,
}: AppIconProps): Gtk.Widget | null {
  const iconName = name?.trim()
  const useCssSize = size === "css"
  const initialSize = typeof size === "number" ? size : 1

  if (!iconName) {
    return null
  }

  if (isFileIcon(iconName)) {
    if (!fileExists(iconName)) {
      return null
    }

    const image = Gtk.Image.new_from_file(iconName)

    image.set_pixel_size(initialSize)
    image.set_css_classes(toCssClasses(className))
    image.set_halign(Gtk.Align.CENTER)
    image.set_valign(Gtk.Align.CENTER)

    if (useCssSize) {
      trackCssIconSize(image, (nextSize) => image.set_pixel_size(nextSize))
    }

    return image
  }

  const theme = getPapirusTheme()

  if (!theme.has_icon(iconName)) {
    return null
  }

  const paintable = lookupPapirusIcon(iconName, initialSize)
  const image = Gtk.Image.new_from_paintable(paintable)

  image.set_pixel_size(initialSize)
  image.set_css_classes(toCssClasses(className))
  image.set_halign(Gtk.Align.CENTER)
  image.set_valign(Gtk.Align.CENTER)
  image.set_tooltip_text(`${PAPIRUS_THEME_NAME}: ${iconName}`)

  if (useCssSize) {
    trackCssIconSize(image, (nextSize) => {
      image.set_from_paintable(lookupPapirusIcon(iconName, nextSize))
      image.set_pixel_size(nextSize)
    })
  }

  return image
}
