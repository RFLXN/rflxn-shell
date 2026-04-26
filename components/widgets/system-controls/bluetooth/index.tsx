import IconOnlyWidget from "../IconOnlyWidget"
import { bluetoothIconName, hasBluetoothAdapter } from "./store"

export default function BluetoothControl() {
  return (
    <IconOnlyWidget
      class="widget-system-controls-bluetooth"
      iconName={bluetoothIconName}
      visible={hasBluetoothAdapter}
    />
  )
}
