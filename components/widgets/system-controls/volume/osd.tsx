import Cairo from "cairo"
import { Accessor, createState, onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import type Gdk from "gi://Gdk?version=4.0"
import { Astal, Gtk } from "ags/gtk4"
import Icon from "../../../icon"
import { volumeState, type VolumeState } from "./store"

type VolumeOsdProps = {
  gdkmonitor?: Gdk.Monitor
}

type VolumeOsdAction = "muted" | "unmuted" | "volume-down" | "volume-up"

type VolumeOsdSnapshot = {
  action: VolumeOsdAction
  iconName: string
  muted: boolean
  percentLabel: string
  title: string
  volume: number
  volumePercent: number
}

const VOLUME_OSD_TIMEOUT_MS = 1150
const VOLUME_OSD_TRANSITION_MS = 160
const VOLUME_OSD_PROGRESS_WIDTH = 112
const VOLUME_OSD_PROGRESS_HEIGHT = 8

const INITIAL_VOLUME_OSD_SNAPSHOT: VolumeOsdSnapshot = {
  action: "volume-up",
  iconName: "volume_down",
  muted: false,
  percentLabel: "0%",
  title: "Volume",
  volume: 0,
  volumePercent: 0,
}

function clampVolume(volume: number) {
  return Math.max(0, Math.min(volume, 1))
}

function isAccessor<T>(value: T | Accessor<T>): value is Accessor<T> {
  return value instanceof Accessor
}

function readAccessor<T>(value: T | Accessor<T>) {
  return isAccessor(value) ? value.peek() : value
}

function hasRelevantVolumeChange(prev: VolumeState, next: VolumeState) {
  return (
    prev.muted !== next.muted ||
    prev.volumePercent !== next.volumePercent
  )
}

function getVolumeIconName(state: VolumeState) {
  if (state.muted) return "volume_mute"
  if (state.volumePercent <= 0) return "volume_off"
  if (state.volumePercent >= 50) return "volume_up"

  return "volume_down"
}

function getVolumeOsdAction(
  prev: VolumeState,
  next: VolumeState,
): VolumeOsdAction {
  if (next.muted) return "muted"
  if (prev.muted && !next.muted) return "unmuted"
  if (next.volumePercent < prev.volumePercent) return "volume-down"

  return "volume-up"
}

function getVolumeOsdTitle(action: VolumeOsdAction) {
  switch (action) {
    case "muted":
      return "Sound Off"
    case "unmuted":
      return "Sound On"
    case "volume-down":
      return "Volume Down"
    case "volume-up":
      return "Volume Up"
  }
}

function createVolumeOsdSnapshot(
  prev: VolumeState,
  next: VolumeState,
): VolumeOsdSnapshot {
  const action = getVolumeOsdAction(prev, next)
  const muted = next.muted

  return {
    action,
    iconName: getVolumeIconName(next),
    muted,
    percentLabel: muted ? "Muted" : `${next.volumePercent}%`,
    title: getVolumeOsdTitle(action),
    volume: muted ? 0 : clampVolume(next.volume),
    volumePercent: next.volumePercent,
  }
}

function getVolumeOsdClassName(snapshot: VolumeOsdSnapshot) {
  const classNames = [
    "widget-system-controls-volume-osd-card",
    `is-${snapshot.action}`,
  ]

  if (snapshot.muted) {
    classNames.push("is-muted")
  } else if (snapshot.volumePercent > 100) {
    classNames.push("is-boosted")
  }

  return classNames.join(" ")
}

function roundedRectangle(
  cr: Cairo.Context,
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number,
) {
  const right = x + width
  const bottom = y + height

  cr.newSubPath()
  cr.arc(right - radius, y + radius, radius, -Math.PI / 2, 0)
  cr.arc(right - radius, bottom - radius, radius, 0, Math.PI / 2)
  cr.arc(x + radius, bottom - radius, radius, Math.PI / 2, Math.PI)
  cr.arc(x + radius, y + radius, radius, Math.PI, Math.PI * 1.5)
  cr.closePath()
}

function VolumeOsdProgress({
  tone,
  value,
}: {
  tone?: Accessor<string>
  value: number | Accessor<number>
}) {
  return (
    <drawingarea
      class="widget-system-controls-volume-osd-progress"
      contentWidth={VOLUME_OSD_PROGRESS_WIDTH}
      contentHeight={VOLUME_OSD_PROGRESS_HEIGHT}
      $={(self) => {
        let progress = clampVolume(readAccessor(value))

        self.set_draw_func((_area, cr, width, height) => {
          const color = self.get_color()
          const radius = height / 2
          const fillWidth = Math.max(height, width * progress)

          cr.save()
          roundedRectangle(cr, 0, 0, width, height, radius)
          cr.setSourceRGBA(
            color.red,
            color.green,
            color.blue,
            color.alpha * 0.18,
          )
          cr.fill()

          if (progress > 0) {
            roundedRectangle(cr, 0, 0, fillWidth, height, radius)
            cr.setSourceRGBA(color.red, color.green, color.blue, color.alpha)
            cr.fill()
          }

          cr.restore()
        })

        const unsubscribes: Array<() => void> = []

        if (isAccessor(value)) {
          unsubscribes.push(
            value.subscribe(() => {
              progress = clampVolume(readAccessor(value))
              self.queue_draw()
            }),
          )
        }

        if (tone) {
          unsubscribes.push(tone.subscribe(() => self.queue_draw()))
        }

        onCleanup(() => {
          for (const unsubscribe of unsubscribes) {
            unsubscribe()
          }
        })
      }}
    />
  )
}

export default function VolumeOsd({ gdkmonitor }: VolumeOsdProps) {
  const monitorProps = gdkmonitor ? { gdkmonitor } : {}
  const [visible, setVisible] = createState(false)
  const [revealed, setRevealed] = createState(false)
  const [snapshot, setSnapshot] = createState<VolumeOsdSnapshot>(
    INITIAL_VOLUME_OSD_SNAPSHOT,
  )
  const progressValue = snapshot.as((current) => current.volume)
  const progressTone = snapshot.as((current) => {
    if (current.muted) return "muted"
    if (current.volumePercent > 100) return "boosted"

    return "normal"
  })

  let previousVolumeState = volumeState.peek()
  let revealIdleId = 0
  let hideTimeoutId = 0
  let unmapTimeoutId = 0

  function clearTimeout(id: number) {
    if (id === 0) return

    GLib.source_remove(id)
  }

  function clearScheduledHides() {
    clearTimeout(revealIdleId)
    clearTimeout(hideTimeoutId)
    clearTimeout(unmapTimeoutId)
    revealIdleId = 0
    hideTimeoutId = 0
    unmapTimeoutId = 0
  }

  function hideOsd() {
    hideTimeoutId = 0
    setRevealed(false)

    unmapTimeoutId = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      VOLUME_OSD_TRANSITION_MS,
      () => {
        unmapTimeoutId = 0
        setVisible(false)
        return GLib.SOURCE_REMOVE
      },
    )
  }

  function showOsd(nextSnapshot: VolumeOsdSnapshot) {
    clearScheduledHides()
    setSnapshot(nextSnapshot)
    setVisible(true)

    revealIdleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      revealIdleId = 0
      setRevealed(true)
      return GLib.SOURCE_REMOVE
    })

    hideTimeoutId = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      VOLUME_OSD_TIMEOUT_MS,
      () => {
        hideOsd()
        return GLib.SOURCE_REMOVE
      },
    )
  }

  function handleVolumeStateChange(next: VolumeState) {
    const prev = previousVolumeState

    previousVolumeState = next

    if (!next.hasDefaultSpeaker) {
      clearScheduledHides()
      setRevealed(false)
      setVisible(false)
      return
    }

    if (!prev.hasDefaultSpeaker || !hasRelevantVolumeChange(prev, next)) {
      return
    }

    showOsd(createVolumeOsdSnapshot(prev, next))
  }

  const card = (
    <box
      class={snapshot.as(getVolumeOsdClassName)}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={12}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      canTarget={false}
    >
      <centerbox
        class="widget-system-controls-volume-osd-icon-container"
        centerWidget={(
          <Icon
            name={snapshot.as((current) => current.iconName)}
            class="widget-system-controls-volume-osd-icon"
            size={44}
          />
        ) as Gtk.Widget}
      />
      <label
        class="widget-system-controls-volume-osd-title text"
        label={snapshot.as((current) => current.title)}
        xalign={0.5}
      />
      <VolumeOsdProgress tone={progressTone} value={progressValue} />
      <label
        class="widget-system-controls-volume-osd-percent text"
        label={snapshot.as((current) => current.percentLabel)}
        xalign={0.5}
      />
    </box>
  ) as Gtk.Widget
  const revealer = (
    <revealer
      class="widget-system-controls-volume-osd-revealer"
      revealChild={revealed}
      transitionDuration={VOLUME_OSD_TRANSITION_MS}
      transitionType={Gtk.RevealerTransitionType.CROSSFADE}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      canTarget={false}
      child={card}
    />
  ) as Gtk.Widget
  const shell = (
    <box
      class="widget-system-controls-volume-osd-shell"
      halign={Gtk.Align.FILL}
      valign={Gtk.Align.FILL}
      hexpand
      vexpand
      canTarget={false}
    >
      {revealer}
    </box>
  ) as Gtk.Widget

  return (
    <window
      {...monitorProps}
      name="system-controls-volume-osd"
      namespace="system-controls-volume-osd"
      class="widget-system-controls-volume-osd-window"
      visible={visible}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.NONE}
      canTarget={false}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM
      }
      $={() => {
        const unsubscribe = volumeState.subscribe(handleVolumeStateChange)

        onCleanup(() => {
          unsubscribe()
          clearScheduledHides()
        })
      }}
    >
      {shell}
    </window>
  )
}
