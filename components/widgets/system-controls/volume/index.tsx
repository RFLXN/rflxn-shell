import type { Accessor } from "ags"
import PercentageWidget from "../PercentageWidget"
import { defaultSpeakerVolumePercent, volumeState } from "./store"

type VolumeControlProps = {
  value?: number | Accessor<number>
}

export default function VolumeControl({
  value = defaultSpeakerVolumePercent,
}: VolumeControlProps) {
  const className = volumeState.as((state) => {
    if (state.muted) {
      return "widget-system-controls-volume is-muted"
    }

    if (state.volumePercent > 100) {
      return "widget-system-controls-volume is-boosted"
    }

    return "widget-system-controls-volume"
  })
  const iconName = volumeState.as((state) =>
    state.muted ? "volume_mute" : "volume_down",
  )

  return (
    <PercentageWidget
      class={className}
      iconName={iconName}
      value={value}
    />
  )
}
