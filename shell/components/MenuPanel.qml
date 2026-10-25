import QtQuick
import qs.services

// Glass container for a pull-down menu. Fill `model` with plain objects:
//   { text, shortcut?, separator?, header?, enabled?, checked?, checkable?, icon?, action: fn }
Item {
    id: root

    property var model: []
    property point windowOffset: Qt.point(0, 0)
    property size screenSize: Qt.size(1920, 1080)
    property real minWidth: 220
    signal done()

    implicitWidth: {
        let m = minWidth;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it) m = Math.max(m, it.implicitWidth + (it.shortcut ? 70 : 10));
        }
        return m;
    }
    implicitHeight: col.implicitHeight + 10

    // Opening animation: a quick fade+drop like macOS menus.
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: 90 } }

    Glass {
        anchors.fill: parent
        radius: Theme.menuRadius
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.55
        bezel: 10
        refraction: 6
        shadowStrength: 0.8
    }

    Column {
        id: col
        y: 5
        width: parent.width

        Repeater {
            id: rep
            model: root.model
            MenuItem {
                required property var modelData
                width: col.width
                text: modelData.text ?? ""
                shortcut: modelData.shortcut ?? ""
                separator: modelData.separator ?? false
                header: modelData.header ?? false
                available: modelData.enabled ?? true
                checkable: modelData.checkable ?? false
                checked: modelData.checked ?? false
                icon: modelData.icon ?? ""
                onTriggered: {
                    root.done();
                    if (modelData.action) modelData.action();
                }
            }
        }
    }
}
