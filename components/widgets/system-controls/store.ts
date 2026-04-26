import {
  GLOBAL_MENU_TRANSITION_DURATION,
  closeMenu,
  isMenuRevealed,
  isMenuVisible,
  openMenu,
  toggleMenu,
} from "../../global-store"

export const SYSTEM_CONTROLS_MENU_ID = "system-controls"
export const SYSTEM_CONTROLS_MENU_TRANSITION_DURATION =
  GLOBAL_MENU_TRANSITION_DURATION

export const isSystemControlsMenuVisible = isMenuVisible(
  SYSTEM_CONTROLS_MENU_ID,
)
export const isSystemControlsMenuRevealed = isMenuRevealed(
  SYSTEM_CONTROLS_MENU_ID,
)

export function openSystemControlsMenu() {
  openMenu(SYSTEM_CONTROLS_MENU_ID)
}

export function closeSystemControlsMenu() {
  closeMenu(SYSTEM_CONTROLS_MENU_ID)
}

export function toggleSystemControlsMenu() {
  toggleMenu(SYSTEM_CONTROLS_MENU_ID)
}
