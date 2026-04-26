import { onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import Gdk from "gi://Gdk?version=4.0"
import PangoCairo from "gi://PangoCairo?version=1.0"
import { Gtk } from "ags/gtk4"
import { focusedWindowTitle } from "../store"

const WINDOW_TITLE_VISIBLE_WIDTH = 480
const WINDOW_TITLE_SCROLL_MIN_WIDTH = WINDOW_TITLE_VISIBLE_WIDTH
const WINDOW_TITLE_CONTENT_HEIGHT = 20
const WINDOW_TITLE_SCROLL_INTERVAL_MS = 16
const WINDOW_TITLE_SCROLL_SPEED_PX_PER_SECOND = 32
const WINDOW_TITLE_START_PAUSE_US = 1_200_000
const WINDOW_TITLE_END_PAUSE_US = 1_600_000

type ScrollPhase = "start-pause" | "scrolling" | "end-pause"

function bindWindowTitleDrawing(area: Gtk.DrawingArea) {
  let title = focusedWindowTitle.peek()
  let titleWidth = 0
  let scrollOffset = 0
  let timeoutId = 0
  let idleId = 0
  let phase: ScrollPhase = "start-pause"
  let phaseStartedAt = GLib.get_monotonic_time()
  let lastTickAt = phaseStartedAt

  const getMaxScroll = () =>
    Math.max(0, titleWidth - WINDOW_TITLE_SCROLL_MIN_WIDTH)

  const measureTitle = () => {
    const layout = area.create_pango_layout(title)

    layout.set_single_paragraph_mode(true)
    titleWidth = layout.get_pixel_size()[0]
  }

  const stopTimer = () => {
    if (timeoutId === 0) return

    GLib.source_remove(timeoutId)
    timeoutId = 0
  }

  const resetScroll = () => {
    phase = "start-pause"
    phaseStartedAt = GLib.get_monotonic_time()
    lastTickAt = phaseStartedAt
    scrollOffset = 0
  }

  const tick = () => {
    const maxScroll = getMaxScroll()

    if (maxScroll <= 1) {
      resetScroll()
      area.queue_draw()
      timeoutId = 0
      return GLib.SOURCE_REMOVE
    }

    const now = GLib.get_monotonic_time()

    if (phase === "start-pause") {
      scrollOffset = 0

      if (now - phaseStartedAt >= WINDOW_TITLE_START_PAUSE_US) {
        phase = "scrolling"
        phaseStartedAt = now
        lastTickAt = now
      }

      area.queue_draw()
      return GLib.SOURCE_CONTINUE
    }

    if (phase === "end-pause") {
      scrollOffset = maxScroll

      if (now - phaseStartedAt >= WINDOW_TITLE_END_PAUSE_US) {
        resetScroll()
      }

      area.queue_draw()
      return GLib.SOURCE_CONTINUE
    }

    const elapsedSeconds = (now - lastTickAt) / 1_000_000

    scrollOffset = Math.min(
      maxScroll,
      scrollOffset + elapsedSeconds * WINDOW_TITLE_SCROLL_SPEED_PX_PER_SECOND,
    )
    lastTickAt = now

    if (scrollOffset >= maxScroll) {
      phase = "end-pause"
      phaseStartedAt = now
    }

    area.queue_draw()
    return GLib.SOURCE_CONTINUE
  }

  const startTimerIfNeeded = () => {
    if (!area.get_root()) return

    measureTitle()

    if (getMaxScroll() <= 1) {
      stopTimer()
      resetScroll()
      area.queue_draw()
      return
    }

    if (timeoutId !== 0) return

    phaseStartedAt = GLib.get_monotonic_time()
    lastTickAt = phaseStartedAt
    timeoutId = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      WINDOW_TITLE_SCROLL_INTERVAL_MS,
      tick,
    )
  }

  const queueRefresh = () => {
    if (idleId !== 0) return

    idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      idleId = 0
      stopTimer()
      resetScroll()
      startTimerIfNeeded()

      return GLib.SOURCE_REMOVE
    })
  }

  const syncTitle = () => {
    title = focusedWindowTitle.peek()
    queueRefresh()
  }
  const unsubscribe = focusedWindowTitle.subscribe(syncTitle)
  const mapSignalId = area.connect("map", queueRefresh)
  const unmapSignalId = area.connect("unmap", stopTimer)
  const rootSignalId = area.connect("notify::root", () => {
    if (area.get_root()) {
      queueRefresh()
    } else {
      stopTimer()
    }
  })

  area.set_draw_func((self, cr, width, height) => {
    const layout = self.create_pango_layout(title)

    layout.set_single_paragraph_mode(true)
    titleWidth = layout.get_pixel_size()[0]

    const titleHeight = layout.get_pixel_size()[1]
    const maxScroll = getMaxScroll()
    const x = maxScroll > 1 ? -scrollOffset : 0
    const y = Math.max(0, Math.floor((height - titleHeight) / 2))

    cr.save()
    cr.rectangle(0, 0, Math.min(width, WINDOW_TITLE_VISIBLE_WIDTH), height)
    cr.clip()
    cr.moveTo(x, y)
    Gdk.cairo_set_source_rgba(cr, self.get_color())
    PangoCairo.show_layout(cr, layout)
    cr.restore()
  })

  queueRefresh()

  onCleanup(() => {
    if (idleId !== 0) {
      GLib.source_remove(idleId)
      idleId = 0
    }

    stopTimer()
    unsubscribe()
    area.disconnect(mapSignalId)
    area.disconnect(unmapSignalId)
    area.disconnect(rootSignalId)
  })
}

export default function WindowTitleWidget() {
  return (
    <drawingarea
      class="widget-window-title text"
      contentWidth={WINDOW_TITLE_VISIBLE_WIDTH}
      contentHeight={WINDOW_TITLE_CONTENT_HEIGHT}
      widthRequest={WINDOW_TITLE_VISIBLE_WIDTH}
      halign={Gtk.Align.START}
      valign={Gtk.Align.CENTER}
      $={bindWindowTitleDrawing}
    />
  )
}
