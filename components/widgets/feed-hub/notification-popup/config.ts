import configJson from "inline:../../../../notification-popups.json"

export type NotificationPopupPosition =
  | "top-left"
  | "top-right"
  | "bottom-left"
  | "bottom-right"

export type NotificationPopupsConfig = {
  monitor: string
  position: NotificationPopupPosition
  timeoutMs: number
  maxVisible: number
}

const DEFAULT_NOTIFICATION_POPUPS_CONFIG: NotificationPopupsConfig = {
  monitor: "DP-3",
  position: "top-right",
  timeoutMs: 6000,
  maxVisible: 3,
}

const POSITION_VALUES = [
  "top-left",
  "top-right",
  "bottom-left",
  "bottom-right",
] as const

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function isNotificationPopupPosition(
  value: unknown,
): value is NotificationPopupPosition {
  return (
    typeof value === "string" &&
    POSITION_VALUES.includes(value as NotificationPopupPosition)
  )
}

function normalizePositiveInteger(value: unknown, fallback: number) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return fallback
  }

  return Math.max(1, Math.round(value))
}

function parseNotificationPopupsConfig(
  json: string,
): NotificationPopupsConfig {
  try {
    const parsed = JSON.parse(json) as unknown

    if (!isRecord(parsed)) {
      console.error("Invalid notification popup config", parsed)
      return DEFAULT_NOTIFICATION_POPUPS_CONFIG
    }

    return {
      monitor: typeof parsed.monitor === "string" && parsed.monitor.trim()
        ? parsed.monitor
        : DEFAULT_NOTIFICATION_POPUPS_CONFIG.monitor,
      position: isNotificationPopupPosition(parsed.position)
        ? parsed.position
        : DEFAULT_NOTIFICATION_POPUPS_CONFIG.position,
      timeoutMs: normalizePositiveInteger(
        parsed.timeoutMs,
        DEFAULT_NOTIFICATION_POPUPS_CONFIG.timeoutMs,
      ),
      maxVisible: normalizePositiveInteger(
        parsed.maxVisible,
        DEFAULT_NOTIFICATION_POPUPS_CONFIG.maxVisible,
      ),
    }
  } catch (error) {
    console.error("Failed to parse notification popup config", error)
    return DEFAULT_NOTIFICATION_POPUPS_CONFIG
  }
}

export const notificationPopupsConfig =
  parseNotificationPopupsConfig(configJson)
