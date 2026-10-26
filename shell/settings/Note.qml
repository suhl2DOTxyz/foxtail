import QtQuick
import qs.services
import qs.components

// Secondary explanatory text under a group.
Label {
    width: parent?.width ?? 0
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    font.pixelSize: 12
    color: Theme.textSecondary
}
