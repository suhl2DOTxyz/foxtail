import QtQuick
import qs.services

// Glass container for a pull-down menu. Fill `model` with plain objects:
//   { text, shortcut?, separator?, header?, enabled?, checked?, checkable?, icon?,
//     action: fn, submenu?: [ ...same shape... ] }
// A submenu opens beside its row on hover, as on macOS; moving to another row
// closes it after a short grace period, so the pointer can travel diagonally
// into the submenu without it snapping shut.
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
            if (it) m = Math.max(m, it.implicitWidth + (it.shortcut || it.hasSubmenu ? 70 : 10));
        }
        return m;
    }
    implicitHeight: col.implicitHeight + 10

    // Opening animation: a quick fade+drop like macOS menus.
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: Theme.ms(90) } }

    Glass {
        anchors.fill: parent
        radius: Theme.menuRadius
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.85
        bezel: 10
        shadowStrength: 0.8
    }

    // ---- submenus ----
    property int openSub: -1
    Timer {
        id: switchSub
        property int target: -1
        interval: 220
        onTriggered: root.openSub = target
    }
    function hoverRow(i, hasSubmenu) {
        if (root.openSub === -1 && hasSubmenu) {
            switchSub.stop();
            root.openSub = i;
            return;
        }
        if (root.openSub === i) {
            switchSub.stop();
            return;
        }
        switchSub.target = hasSubmenu ? i : -1;
        switchSub.restart();
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
                required property int index
                width: col.width
                text: modelData.text ?? ""
                shortcut: modelData.shortcut ?? ""
                separator: modelData.separator ?? false
                header: modelData.header ?? false
                available: modelData.enabled ?? true
                checkable: modelData.checkable ?? false
                checked: modelData.checked ?? false
                icon: modelData.icon ?? ""
                hasSubmenu: !!modelData.submenu
                open: root.openSub === index
                onEntered: root.hoverRow(index, hasSubmenu && available)
                onTriggered: {
                    root.done();
                    if (modelData.action) modelData.action();
                }
            }
        }
    }

    // Pointer inside this menu (a parent menu keeps its submenu open then).
    readonly property bool hovered: hover.hovered
    HoverHandler { id: hover }

    Loader {
        id: subLoader
        active: root.openSub >= 0 && !!root.model[root.openSub]?.submenu
        // Loaded by URL: a component can't contain itself directly.
        source: active ? Qt.resolvedUrl("MenuPanel.qml") : ""
        readonly property Item row: active ? rep.itemAt(root.openSub) : null
        // Open to the right, or to the left when there is no room.
        readonly property bool flip: root.mapToItem(null, root.width, 0).x + root.windowOffset.x
                                     + (item?.width ?? 0) > root.screenSize.width - 6
        x: flip ? -(item?.width ?? 0) + 4 : root.width - 4
        y: (row?.y ?? 0) + col.y - 5
        onLoaded: {
            item.minWidth = 180;
            item.windowOffset = Qt.binding(() => root.windowOffset);
            item.screenSize = Qt.binding(() => root.screenSize);
            item.model = Qt.binding(() => root.model[root.openSub]?.submenu ?? []);
            item.done.connect(root.done);
        }
    }
    Connections {
        target: subLoader.item
        function onHoveredChanged() { if (subLoader.item.hovered) switchSub.stop(); }
    }
}
