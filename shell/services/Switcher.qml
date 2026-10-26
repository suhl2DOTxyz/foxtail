pragma Singleton
import QtQuick
import Quickshell

// ⌘Tab: while ⌘ is held, Tab steps through running apps (most recent first);
// releasing ⌘ switches to the selected one. A quick ⌘Tab tap switches to the
// previous app without showing anything, as on macOS.
Singleton {
    id: root

    property bool active: false     // ⌘ held, cycling
    property bool shown: false      // the switcher is on screen
    property var apps: []
    property int index: 0

    function step(dir) {
        if (!active) {
            apps = Apps.running;
            if (apps.length === 0) return;
            active = true;
            index = 0;
            showDelay.restart();
        }
        index = (index + dir + apps.length) % apps.length;
    }

    function commit() {
        if (!active) return;
        const id = apps[index];
        close();
        if (id) Apps.focus(id);
    }

    function close() {
        active = false;
        shown = false;
        showDelay.stop();
    }

    Timer {
        id: showDelay
        interval: 140
        onTriggered: root.shown = root.active
    }
}
