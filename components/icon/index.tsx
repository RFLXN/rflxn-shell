import Cairo from "cairo"
import { Accessor, onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import Gdk from "gi://Gdk?version=4.0"
import GdkPixbuf from "gi://GdkPixbuf?version=2.0"
import { Gtk } from "ags/gtk4"

type IconProps = {
  class?: string | Accessor<string>
  name: string | Accessor<string>
  size?: number | "css"
  visible?: boolean | Accessor<boolean>
}

const materialIconsDir = GLib.build_filenamev([
  SRC,
  "assets",
  "icons",
  "material",
])

function toMaterialIconPath(name: string) {
  return GLib.build_filenamev([materialIconsDir, `${name}.svg`])
}

function isAccessor<T>(value: T | Accessor<T>): value is Accessor<T> {
  return value instanceof Accessor
}

function readIconName(name: string | Accessor<string>) {
  return isAccessor(name) ? name.peek() : name
}

function createIconSurface(name: string) {
  const pixbuf = GdkPixbuf.Pixbuf.new_from_file(toMaterialIconPath(name))
  const texture = Gdk.Texture.new_for_pixbuf(pixbuf)
  const [iconSurfaceFd, iconSurfacePath] = GLib.file_open_tmp("new-shell-icon-XXXXXX.png")

  GLib.close(iconSurfaceFd)
  texture.save_to_png(iconSurfacePath)

  const surface = Cairo.ImageSurface.createFromPNG(iconSurfacePath)

  GLib.remove(iconSurfacePath)

  return {
    surface,
    width: pixbuf.get_width(),
    height: pixbuf.get_height(),
  }
}

export default function Icon({
  name,
  class: className,
  size,
  visible = true,
}: IconProps) {
  // We draw icons manually instead of using `<image file="...svg" />` because
  // plain file-backed images do not follow CSS `color` in this setup.
  // A simpler pixbuf-based approach also did not reliably track runtime style
  // changes, so we render through a DrawingArea and use the SVG surface as a
  // mask, then fill it with the widget's current foreground color.
  //
  // `Gdk.cairo_set_source_pixbuf()` would make the masking step simpler, but it
  // is deprecated. GTK recommends going through `Gdk.Texture`, but the current
  // GJS/Cairo bindings available in this repo do not expose the direct
  // in-memory Cairo image-surface path cleanly, so we materialize a temporary
  // PNG surface once and reuse it for drawing.
  let icon = createIconSurface(readIconName(name))
  const useCssSize = size === "css"
  const width = typeof size === "number" ? size : icon.width
  const height = typeof size === "number" ? size : icon.height
  const sizeProps = useCssSize
    ? {}
    : {
        contentWidth: width,
        contentHeight: height,
      }

  return (
    <drawingarea
      {...sizeProps}
      class={className}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      visible={visible}
      $={(self) => {
        self.set_draw_func((_area, cr, drawWidth, drawHeight) => {
          cr.save()
          cr.scale(drawWidth / icon.width, drawHeight / icon.height)

          cr.setSourceSurface(icon.surface, 0, 0)
          const mask = cr.getSource()

          Gdk.cairo_set_source_rgba(cr, self.get_color())
          cr.mask(mask)
          cr.restore()
        })

        self.connect("notify::css-classes", () => self.queue_draw())
        self.connect("notify::root", () => self.queue_draw())

        if (isAccessor(name)) {
          const unsubscribe = name.subscribe(() => {
            icon = createIconSurface(readIconName(name))
            self.queue_draw()
          })

          onCleanup(unsubscribe)
        }
      }}
    />
  )
}
