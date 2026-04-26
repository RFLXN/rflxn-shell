import { Gtk } from "ags/gtk4"
import type Cairo from "cairo"

type BarSkirtProps = {
  side: "left" | "right"
  width?: number
  height?: number
}

function drawLeftSkirt(
  cr: Cairo.Context,
  width: number,
  height: number,
  color: { red: number; green: number; blue: number; alpha: number },
) {
  cr.setSourceRGBA(color.red, color.green, color.blue, color.alpha)
  cr.moveTo(0, 0)
  cr.lineTo(width, 0)

  // Draw the inward quarter-ellipse from the rail edge to the outer edge.
  cr.save()
  cr.translate(width, height)
  cr.scale(width, height)
  cr.arcNegative(0, 0, 1, -Math.PI / 2, -Math.PI)
  cr.restore()

  cr.closePath()
  cr.fill()
}

export default function BarSkirt({
  side,
  width = 16,
  height = 17,
}: BarSkirtProps) {
  return (
    <drawingarea
      class={`bar-skirt bar-skirt-${side}`}
      contentWidth={width}
      contentHeight={height}
      $={(self) => {
        self.set_draw_func((_area, cr, actualWidth, actualHeight) => {
          const color = self.get_color()

          if (side === "right") {
            cr.save()
            cr.translate(actualWidth, 0)
            cr.scale(-1, 1)
            drawLeftSkirt(cr, actualWidth, actualHeight, color)
            cr.restore()
            return
          }

          drawLeftSkirt(cr, actualWidth, actualHeight, color)
        })
      }}
    />
  )
}
