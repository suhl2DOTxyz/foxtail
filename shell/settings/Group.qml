import QtQuick
import qs.services

// An inset-grouped block of rows, as in macOS System Settings.
Rectangle {
    default property alias rows: groupCol.data
    width: parent?.width ?? 0
    height: groupCol.implicitHeight
    radius: Theme.liquid ? 18 : 9
    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.03)
    border.color: Theme.separator
    Column { id: groupCol; width: parent.width }
}
