import { Accessor } from "ags"
import Icon from "../../icon"

type IconOnlyWidgetProps = {
  class?: string | Accessor<string>
  iconName: string | Accessor<string>
  size?: number
  visible?: boolean | Accessor<boolean>
}

function isAccessor<T>(value: T | Accessor<T>): value is Accessor<T> {
  return value instanceof Accessor
}

function getClassName(className: string | Accessor<string> | undefined) {
  const baseClassName = "widget-system-controls-icon"

  if (!className) {
    return `${baseClassName} text`
  }

  if (isAccessor(className)) {
    return className.as((currentClassName) =>
      currentClassName
        ? `${baseClassName} ${currentClassName} text`
        : `${baseClassName} text`,
    )
  }

  return `${baseClassName} ${className} text`
}

export default function IconOnlyWidget({
  class: className,
  iconName,
  size = 16,
  visible = true,
}: IconOnlyWidgetProps) {
  return (
    <Icon
      name={iconName}
      class={getClassName(className)}
      size={size}
      visible={visible}
    />
  )
}
