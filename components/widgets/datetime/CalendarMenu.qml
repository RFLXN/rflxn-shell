import QtQuick
import "../../menu"

SideMenu {
    id: root

    alignment: "center"
    contentPadding: 18
    cornerRadius: 24
    direction: "top"
    menuHeight: 380
    menuId: "calendar"
    menuMargin: 0
    menuWidth: 360

    CalendarView {
        anchors.fill: parent
    }
}
