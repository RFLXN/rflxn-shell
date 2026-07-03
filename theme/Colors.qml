pragma Singleton

import QtQuick

QtObject {
    readonly property color barBg: "#161B1F"
    readonly property color barFg: "#E3ECE8"
    readonly property color barBorder: "#2A3338"

    readonly property color widgetBg: "#1C2227"
    readonly property color widgetBgHover: "#252D33"
    readonly property color widgetBgActive: "#1D4E4A"
    readonly property color widgetBorder: "#2A3338"

    readonly property color textPrimary: "#E3ECE8"
    readonly property color textSecondary: "#B6C4BE"
    readonly property color textMuted: "#7F9089"
    readonly property color textOnAccent: "#E8FFFB"

    readonly property color accent: "#2BB6A8"
    readonly property color accentSoft: "#1D4E4A"
    readonly property color accentStrong: "#1F8F86"

    readonly property color success: "#39C77A"
    readonly property color warning: "#D6A84B"
    readonly property color critical: "#D35D6E"
    readonly property color info: accent

    readonly property color separator: "#2A3338"
    readonly property color iconColor: textSecondary
}
