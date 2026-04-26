import { createState, type Accessor } from "ags"
import type { ShutdownConfirmationAction } from "./shutdown-confirmation-overlay"

export type GlobalMenuId = string

export const GLOBAL_MENU_TRANSITION_DURATION = 500
export const APP_LAUNCHER_MENU_ID = "app-launcher"
export const APP_LAUNCHER_TRANSITION_DURATION = GLOBAL_MENU_TRANSITION_DURATION
const GLOBAL_MENU_CLOSE_UNMAP_DELAY = GLOBAL_MENU_TRANSITION_DURATION

const [visibleMenu, setVisibleMenu] = createState<GlobalMenuId | null>(null)
const [revealedMenu, setRevealedMenu] = createState<GlobalMenuId | null>(null)
const [shutdownConfirmationAction, setShutdownConfirmationAction] =
  createState<ShutdownConfirmationAction | null>(null)

let transitionToken = 0
let closeTimeout: ReturnType<typeof setTimeout> | null = null

function clearCloseTimeout() {
  if (!closeTimeout) return

  clearTimeout(closeTimeout)
  closeTimeout = null
}

export function openMenu(menuId: GlobalMenuId) {
  const token = ++transitionToken

  clearCloseTimeout()
  setRevealedMenu(null)
  setVisibleMenu(menuId)

  setTimeout(() => {
    if (token !== transitionToken) return

    setRevealedMenu(menuId)
  })
}

export function closeActiveMenu() {
  if (!visibleMenu.peek()) return

  const token = ++transitionToken

  clearCloseTimeout()
  setRevealedMenu(null)

  closeTimeout = setTimeout(() => {
    if (token !== transitionToken) return

    setVisibleMenu(null)
    closeTimeout = null
  }, GLOBAL_MENU_CLOSE_UNMAP_DELAY)
}

export function closeMenu(menuId: GlobalMenuId) {
  if (visibleMenu.peek() !== menuId) return

  closeActiveMenu()
}

export function toggleMenu(menuId: GlobalMenuId) {
  if (visibleMenu.peek() === menuId) {
    closeActiveMenu()
  } else {
    openMenu(menuId)
  }
}

export function isMenuVisible(menuId: GlobalMenuId): Accessor<boolean> {
  return visibleMenu.as((current) => current === menuId)
}

export function isMenuRevealed(menuId: GlobalMenuId): Accessor<boolean> {
  return revealedMenu.as((current) => current === menuId)
}

export const isAnyMenuVisible = visibleMenu.as((current) => current !== null)
export const isAnyMenuRevealed = revealedMenu.as((current) => current !== null)
export const activeMenu = visibleMenu
export const activeRevealedMenu = revealedMenu

export function openAppLauncher() {
  openMenu(APP_LAUNCHER_MENU_ID)
}

export function closeAppLauncher() {
  closeMenu(APP_LAUNCHER_MENU_ID)
}

export function closeGlobalMenus() {
  closeActiveMenu()
  closeShutdownConfirmation()
}

export function toggleAppLauncher() {
  toggleMenu(APP_LAUNCHER_MENU_ID)
}

export function openShutdownConfirmation(action: ShutdownConfirmationAction) {
  closeGlobalMenus()
  setShutdownConfirmationAction(action)
}

export function closeShutdownConfirmation() {
  setShutdownConfirmationAction(null)
}

export const isAppLauncherOpen = isMenuVisible(APP_LAUNCHER_MENU_ID)
export const isAppLauncherVisible = isAppLauncherOpen
export const isAppLauncherRevealed = isMenuRevealed(APP_LAUNCHER_MENU_ID)
export const activeShutdownConfirmationAction = shutdownConfirmationAction
export const isShutdownConfirmationVisible = shutdownConfirmationAction.as(
  (action) => action !== null,
)
