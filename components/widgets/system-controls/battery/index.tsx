import type { Accessor } from "ags"
import PercentageWidget from "../PercentageWidget"
import { batteryClassName, batteryPercentage, hasBattery } from "./store"

type BatteryControlProps = {
  value?: number | Accessor<number>
}

export default function BatteryControl({
  value = batteryPercentage,
}: BatteryControlProps) {
  return (
    <PercentageWidget
      class={batteryClassName}
      iconName="battery_full"
      iconSize={15}
      value={value}
      visible={hasBattery}
    />
  )
}
