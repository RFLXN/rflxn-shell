pragma Singleton

import Quickshell
import QtQuick

Scope {
    id: root

    property date now: new Date()
    property date minuteNow: new Date()

    function update() {
        const next = new Date();
        const minuteChanged = next.getFullYear() !== root.minuteNow.getFullYear()
            || next.getMonth() !== root.minuteNow.getMonth()
            || next.getDate() !== root.minuteNow.getDate()
            || next.getHours() !== root.minuteNow.getHours()
            || next.getMinutes() !== root.minuteNow.getMinutes();

        root.now = next;

        if (minuteChanged)
            root.minuteNow = next;
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: root.update()
    }
}
