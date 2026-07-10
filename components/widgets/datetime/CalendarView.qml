pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../state"

Item {
    id: root

    property bool followToday: true
    readonly property date todayDate: ClockState.minuteNow
    property date viewDate: new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
    readonly property int todayDay: todayDate.getDate()
    readonly property int todayMonth: todayDate.getMonth()
    readonly property int todayYear: todayDate.getFullYear()
    readonly property int viewMonth: viewDate.getMonth()
    readonly property int viewYear: viewDate.getFullYear()
    readonly property bool viewingCurrentMonth: viewYear === todayYear && viewMonth === todayMonth
    readonly property var calendarDays: buildCalendarDays(viewYear, viewMonth, todayYear, todayMonth, todayDay)
    readonly property var weekdayLabels: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    function buildCalendarDays(year, month, todayYear, todayMonth, todayDay) {
        const firstWeekday = new Date(year, month, 1).getDay();
        const days = [];

        for (let index = 0; index < 42; index++) {
            const dayOffset = index - firstWeekday + 1;
            const date = new Date(year, month, dayOffset);
            const inMonth = date.getMonth() === month;

            days.push({
                day: date.getDate(),
                inMonth,
                today: date.getFullYear() === todayYear && date.getMonth() === todayMonth && date.getDate() === todayDay
            });
        }

        return days;
    }

    function currentMonthStart() {
        return new Date(root.todayYear, root.todayMonth, 1);
    }

    function moveMonth(delta) {
        root.viewDate = new Date(root.viewYear, root.viewMonth + delta, 1);
        root.followToday = root.viewingCurrentMonth;
    }

    function monthTitle() {
        return Qt.formatDate(root.viewDate, "MMMM yyyy");
    }

    function todayTitle() {
        return root.viewingCurrentMonth ? Qt.formatDate(root.todayDate, "dddd, MMMM d") : Qt.formatDate(root.viewDate, "MMMM yyyy");
    }

    function resetToToday() {
        root.followToday = true;
        root.viewDate = root.currentMonthStart();
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            width: parent.width
            height: 46
            spacing: 10

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                color: Colors.accentSoft
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    color: Colors.accent
                    font.family: Typography.iconFamily
                    font.pixelSize: 15
                    text: "\uf073"
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - controls.implicitWidth - 10
                spacing: 2

                Text {
                    width: parent.width
                    color: Colors.textPrimary
                    elide: Text.ElideRight
                    font.family: Typography.textFamily
                    font.pixelSize: 15
                    font.weight: Font.ExtraBold
                    text: root.monthTitle()
                }

                Text {
                    width: parent.width
                    color: Colors.textMuted
                    elide: Text.ElideRight
                    font.family: Typography.textFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    text: root.todayTitle()
                }
            }

            Row {
                id: controls

                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Rectangle {
                    width: 28
                    height: 28
                    color: previousArea.containsMouse ? Colors.widgetBgHover : "transparent"
                    radius: height / 2

                    Text {
                        anchors.centerIn: parent
                        color: previousArea.containsMouse ? Colors.textPrimary : Colors.textSecondary
                        font.family: Typography.iconFamily
                        font.pixelSize: 14
                        text: "\uf053"
                    }

                    MouseArea {
                        id: previousArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.moveMonth(-1)
                    }
                }

                Rectangle {
                    width: 48
                    height: 28
                    border.color: root.viewingCurrentMonth ? Colors.accentSoft : Colors.widgetBorder
                    border.width: 1
                    color: todayArea.containsMouse ? Colors.widgetBgHover : root.viewingCurrentMonth ? Colors.accentSoft : "transparent"
                    radius: height / 2

                    Text {
                        anchors.centerIn: parent
                        color: root.viewingCurrentMonth ? Colors.accent : Colors.textSecondary
                        font.family: Typography.textFamily
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        text: "Today"
                    }

                    MouseArea {
                        id: todayArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.resetToToday()
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    color: nextArea.containsMouse ? Colors.widgetBgHover : "transparent"
                    radius: height / 2

                    Text {
                        anchors.centerIn: parent
                        color: nextArea.containsMouse ? Colors.textPrimary : Colors.textSecondary
                        font.family: Typography.iconFamily
                        font.pixelSize: 14
                        text: "\uf054"
                    }

                    MouseArea {
                        id: nextArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.moveMonth(1)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.separator
        }

        Grid {
            width: parent.width
            columns: 7
            columnSpacing: 4
            rowSpacing: 0

            Repeater {
                model: root.weekdayLabels

                Item {
                    id: weekdayCell

                    required property string modelData

                    width: (parent.width - 24) / 7
                    height: 24

                    Text {
                        anchors.centerIn: parent
                        color: Colors.textMuted
                        font.family: Typography.textFamily
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        text: weekdayCell.modelData
                    }
                }
            }
        }

        Grid {
            id: dayGrid

            width: parent.width
            columns: 7
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: root.calendarDays

                Rectangle {
                    id: dayCell

                    required property var modelData

                    width: (dayGrid.width - 24) / 7
                    height: 34
                    color: dayCell.modelData.today ? Colors.accentSoft : "transparent"
                    radius: 7

                    Text {
                        anchors.centerIn: parent
                        color: dayCell.modelData.today ? Colors.accent : dayCell.modelData.inMonth ? Colors.textPrimary : Colors.textMuted
                        font.family: Typography.textFamily
                        font.pixelSize: 13
                        font.weight: dayCell.modelData.today ? Font.ExtraBold : Font.DemiBold
                        text: dayCell.modelData.day
                    }
                }
            }
        }
    }

    onTodayDateChanged: {
        if (root.followToday)
            root.viewDate = root.currentMonthStart();
    }
}
