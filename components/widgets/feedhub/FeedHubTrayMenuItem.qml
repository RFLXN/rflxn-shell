import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../../theme"

Item {
    id: root

    property var entry
    readonly property bool checked: entry?.checkState === Qt.Checked || entry?.checkState === Qt.PartiallyChecked
    readonly property bool entryEnabled: entry?.enabled ?? false
    readonly property bool hovered: itemArea.containsMouse
    readonly property bool isSeparator: entry?.isSeparator ?? false
    readonly property string iconName: String(entry?.icon ?? "")
    signal activated()
    signal submenuDismissRequested()
    signal submenuRequested(var entry, var anchorItem)

    width: 220
    height: isSeparator ? 8 : 28

    Rectangle {
        anchors {
            left: parent.left
            leftMargin: 8
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }

        height: 1
        color: Colors.separator
        visible: root.isSeparator
    }

    Rectangle {
        anchors.fill: parent
        color: root.hovered && root.entryEnabled ? Colors.widgetBgHover : "transparent"
        radius: 6
        visible: !root.isSeparator

        Row {
            anchors {
                left: parent.left
                leftMargin: 8
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }

            spacing: 8

            Item {
                width: 16
                height: 16

                IconImage {
                    id: entryIcon

                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    asynchronous: true
                    implicitSize: 14
                    source: root.iconName
                    visible: root.iconName !== "" && status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    color: root.entryEnabled ? Colors.textSecondary : Colors.textMuted
                    font.family: Typography.iconFamily
                    font.pixelSize: 12
                    text: root.entry?.buttonType === QsMenuButtonType.RadioButton ? (root.checked ? "\uf192" : "\uf111") : (root.checked ? "\uf00c" : "")
                    visible: !entryIcon.visible
                }
            }

            Text {
                width: parent.width - 46
                color: root.entryEnabled ? Colors.textPrimary : Colors.textMuted
                elide: Text.ElideRight
                font.family: Typography.textFamily
                font.pixelSize: 12
                text: String(root.entry?.text ?? "")
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                width: 14
                color: root.entryEnabled ? Colors.textSecondary : Colors.textMuted
                font.family: Typography.iconFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                text: root.entry?.hasChildren ? "\uf054" : ""
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: itemArea

            anchors.fill: parent
            cursorShape: root.entryEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            hoverEnabled: true
            onClicked: {
                if (!root.entryEnabled || !root.entry)
                    return;

                if (root.entry.hasChildren) {
                    root.submenuRequested(root.entry, root);
                    return;
                }

                root.entry.triggered();
                root.activated();
            }
            onEntered: {
                if (root.entryEnabled && root.entry?.hasChildren) {
                    root.submenuRequested(root.entry, root);
                    return;
                }

                root.submenuDismissRequested();
            }
        }
    }
}
