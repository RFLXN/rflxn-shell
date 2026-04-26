import PercentageWidget from "../PercentageWidget"
import { hasBattery } from "./store"

type BatteryControlProps = {
  value?: number
}

export default function BatteryControl({ value = 82 }: BatteryControlProps) {
  return (
    <PercentageWidget
      class="widget-system-controls-battery"
      iconName="battery_full"
      iconSize={15}
      value={value}
      visible={hasBattery}
    />
  )
}
