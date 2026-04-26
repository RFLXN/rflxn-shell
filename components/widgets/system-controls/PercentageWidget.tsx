import Cairo from "cairo"
import { Accessor, onCleanup } from "ags"
import { Gtk } from "ags/gtk4"
import Icon from "../../icon"

type PercentageWidgetProps = {
  class?: string | Accessor<string>
  iconName: string | Accessor<string>
  iconSize?: number
  size?: number
  value?: number | Accessor<number>
  visible?: boolean | Accessor<boolean>
}

function clampPercentage(value: number) {
  return Math.max(0, Math.min(100, value))
}

function formatPercentage(value: number) {
  return `${Math.round(Math.max(0, value))}`
}

function isAccessor<T>(value: T | Accessor<T>): value is Accessor<T> {
  return value instanceof Accessor
}

function getClassName(className: string | Accessor<string> | undefined) {
  if (!className) {
    return "widget-system-controls-percentage"
  }

  if (isAccessor(className)) {
    return className.as((currentClassName) =>
      currentClassName
        ? `widget-system-controls-percentage ${currentClassName}`
        : "widget-system-controls-percentage",
    )
  }

  return `widget-system-controls-percentage ${className}`
}

function readPercentage(value: number | Accessor<number>) {
  return clampPercentage(isAccessor(value) ? value.peek() : value)
}

function readIconName(iconName: string | Accessor<string>) {
  return isAccessor(iconName) ? iconName.peek() : iconName
}

function createIconContent(iconName: string, iconSize: number) {
  return Icon({
    name: iconName,
    class: "widget-system-controls-percentage-icon text",
    size: iconSize,
  }) as Gtk.Widget
}

export default function PercentageWidget({
  class: className,
  iconName,
  iconSize = 18,
  size = 24,
  value = 82,
  visible = true,
}: PercentageWidgetProps) {
  const ring = (
    <drawingarea
      class="widget-system-controls-percentage-ring"
      contentWidth={size}
      contentHeight={size}
      $={(self) => {
        let progress = readPercentage(value) / 100

        self.set_draw_func((_area, cr, width, height) => {
          const color = self.get_color()
          const actualSize = Math.min(width, height)
          const lineWidth = Math.max(2, actualSize * 0.1)
          const radius = (actualSize - lineWidth) / 2
          const centerX = width / 2
          const centerY = height / 2
          const start = -Math.PI / 2
          const end = start + Math.PI * 2 * progress

          cr.setLineWidth(lineWidth)
          cr.setLineCap(Cairo.LineCap.ROUND)

          cr.setSourceRGBA(
            color.red,
            color.green,
            color.blue,
            color.alpha * 0.24,
          )
          cr.arc(centerX, centerY, radius, 0, Math.PI * 2)
          cr.stroke()

          cr.setSourceRGBA(color.red, color.green, color.blue, color.alpha)
          cr.arc(centerX, centerY, radius, start, end)
          cr.stroke()
        })

        const unsubscribes: Array<() => void> = []

        if (isAccessor(value)) {
          unsubscribes.push(
            value.subscribe(() => {
              progress = readPercentage(value) / 100
              self.queue_draw()
            }),
          )
        }

        if (isAccessor(className)) {
          unsubscribes.push(className.subscribe(() => self.queue_draw()))
        }

        onCleanup(() => {
          for (const unsubscribe of unsubscribes) {
            unsubscribe()
          }
        })
      }}
    />
  ) as Gtk.Widget
  const icon = (
    <centerbox
      class="widget-system-controls-percentage-icon-container"
      widthRequest={size}
      heightRequest={size}
      centerWidget={createIconContent(readIconName(iconName), iconSize)}
      $={(self) => {
        const unsubscribes: Array<() => void> = []

        if (isAccessor(iconName)) {
          unsubscribes.push(
            iconName.subscribe(() => {
              self.set_center_widget(
                createIconContent(readIconName(iconName), iconSize),
              )
            }),
          )
        }

        if (isAccessor(className)) {
          unsubscribes.push(
            className.subscribe(() => self.get_center_widget()?.queue_draw()),
          )
        }

        onCleanup(() => {
          for (const unsubscribe of unsubscribes) {
            unsubscribe()
          }
        })
      }}
    />
  ) as Gtk.Widget
  const progressIcon = (
    <overlay
      class="widget-system-controls-percentage-progress"
      widthRequest={size}
      heightRequest={size}
      child={ring}
      $={(self) => {
        self.add_overlay(icon)
        self.set_measure_overlay(icon, false)
      }}
    />
  ) as Gtk.Widget
  const label = (
    <label
      class="widget-system-controls-percentage-value text"
      label={
        isAccessor(value)
          ? value.as((currentValue) => formatPercentage(currentValue))
          : formatPercentage(value)
      }
      valign={Gtk.Align.CENTER}
    />
  ) as Gtk.Widget

  return (
    <box
      class={getClassName(className)}
      spacing={4}
      valign={Gtk.Align.CENTER}
      visible={visible}
    >
      {label}
      {progressIcon}
    </box>
  )
}
