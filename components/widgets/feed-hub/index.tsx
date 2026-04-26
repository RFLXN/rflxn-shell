import { Gtk } from "ags/gtk4"
import Icon from "../../icon"
import { hasNotifications } from "./notification/store"
import { isFeedHubMenuVisible, toggleFeedHubMenu } from "./store"

const FEED_HUB_CELL_SIZE = 32

export default function FeedHubWidget() {
  const iconContent = (
    <Icon name="dynamic_feed" class="widget-feed-hub-icon text" size="css" />
  ) as Gtk.Widget
  const icon = (
    <centerbox
      class="widget-feed-hub-icon-container"
      widthRequest={FEED_HUB_CELL_SIZE}
      heightRequest={FEED_HUB_CELL_SIZE}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      centerWidget={iconContent}
    />
  ) as Gtk.Widget
  const indicator = (
    <box
      class="widget-feed-hub-indicator"
      visible={hasNotifications}
      halign={Gtk.Align.END}
      valign={Gtk.Align.START}
    />
  ) as Gtk.Widget

  const trigger = (
    <overlay
      class={isFeedHubMenuVisible.as((visible) =>
        visible ? "widget-feed-hub is-open" : "widget-feed-hub",
      )}
      widthRequest={FEED_HUB_CELL_SIZE}
      heightRequest={FEED_HUB_CELL_SIZE}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      child={icon}
      $={(self) => {
        self.add_overlay(indicator)
        self.set_measure_overlay(indicator, false)
      }}
    />
  ) as Gtk.Widget

  return (
    <button
      class="widget-feed-hub-button flat"
      widthRequest={FEED_HUB_CELL_SIZE}
      heightRequest={FEED_HUB_CELL_SIZE}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      hasFrame={false}
      child={trigger}
      $={(self) => {
        self.connect("clicked", toggleFeedHubMenu)
      }}
    />
  )
}
