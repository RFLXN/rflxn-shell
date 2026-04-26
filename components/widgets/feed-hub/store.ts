import {
  GLOBAL_MENU_TRANSITION_DURATION,
  closeMenu,
  isMenuRevealed,
  isMenuVisible,
  openMenu,
  toggleMenu,
} from "../../global-store"

export const FEED_HUB_MENU_ID = "feed-hub"
export const FEED_HUB_MENU_TRANSITION_DURATION =
  GLOBAL_MENU_TRANSITION_DURATION

export const isFeedHubMenuVisible = isMenuVisible(FEED_HUB_MENU_ID)
export const isFeedHubMenuRevealed = isMenuRevealed(FEED_HUB_MENU_ID)

export function openFeedHubMenu() {
  openMenu(FEED_HUB_MENU_ID)
}

export function closeFeedHubMenu() {
  closeMenu(FEED_HUB_MENU_ID)
}

export function toggleFeedHubMenu() {
  toggleMenu(FEED_HUB_MENU_ID)
}
