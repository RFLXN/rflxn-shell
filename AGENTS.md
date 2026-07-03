# AGENTS.md

## Project Context

This repository is for rebuilding the user's existing Hyprland shell with
Quickshell.

The original implementation is an AGS-based shell located at:

`/home/rflxn/development/rflxn-shell`

When the user asks to build something "by referencing the original",
"based on the original", or similar wording, use
`/home/rflxn/development/rflxn-shell` as the reference implementation.

Prefer preserving the original shell's behavior, layout, and interaction model
unless the user asks for changes. Quickshell-specific implementation details may
differ, especially where animation or Qt/QML patterns make a cleaner approach
possible.

## Original Color Scheme

The original AGS shell defines its main palette in:

`/home/rflxn/development/rflxn-shell/styles/theme.scss`

Use this palette as the visual baseline when rebuilding components in
Quickshell.

Core surfaces:

- `bar-bg`: `#161B1F`
- `bar-fg`: `#E3ECE8`
- `bar-border`: `#2A3338`
- `widget-bg`: `#1C2227`
- `widget-bg-hover`: `#252D33`
- `widget-bg-active`: `#1D4E4A`
- `widget-border`: `#2A3338`
- `separator`: `#2A3338`

Text:

- `text-primary`: `#E3ECE8`
- `text-secondary`: `#B6C4BE`
- `text-muted`: `#7F9089`
- `text-on-accent`: `#E8FFFB`
- `icon-color`: same as `text-secondary`

Accent:

- `accent`: `#2BB6A8`
- `accent-soft`: `#1D4E4A`
- `accent-strong`: `#1F8F86`
- `info`: same as `accent`

State colors:

- `success`: `#39C77A`
- `warning`: `#D6A84B`
- `critical`: `#D35D6E`

Style notes from the original shell:

- The overall theme is a dark blue-green/charcoal surface with mint-teal
  accents.
- The bar itself uses `bar-bg`; most menus, cards, and popovers use
  `widget-bg` with `widget-border`.
- Hover or selected surfaces generally use `widget-bg-hover` or
  `widget-bg-active`.
- Primary text uses `text-primary`; normal icon and secondary text use
  `text-secondary`; subdued labels and empty states use `text-muted`.
- Accent controls use `accent-soft` as the resting background, `accent` on
  hover, and `accent-strong` for pressed/open states.
- Status colors are semantic: charging/connected uses `success`,
  boosted/connecting/urgent restart uses `warning`, and muted/offline/critical
  notification/shutdown uses `critical`.
- The original uses translucent black only for scrims and shadows, for example
  `rgba(4, 8, 10, 0.68)` on the shutdown overlay scrim and black shadows around
  popups/OSD cards.
- A few contrast-only literals exist in the original: warning-filled states use
  `#15110a` for dark text, and shutdown critical hover uses `#fff0f3` for light
  text.

## System Control Panel Design

Internal panels in the system control menu should use a consistent structure:

- Use one outer card for the whole panel.
- Put the icon and section title in the panel header.
- Keep the panel contents visually flat inside that card.
- Separate subsections with divider-based layout, not nested cards.
- Match the current volume panel's interaction and visual style unless the user
  asks for a different treatment.
