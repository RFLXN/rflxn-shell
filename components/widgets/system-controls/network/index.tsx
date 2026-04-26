import IconOnlyWidget from "../IconOnlyWidget"
import { networkClassName, networkIconName } from "./store"

export default function NetworkControl() {
  return (
    <IconOnlyWidget
      class={networkClassName}
      iconName={networkIconName}
    />
  )
}
