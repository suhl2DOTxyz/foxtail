pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen lock state. It is mirrored to a file in the runtime directory so a
// shell that restarts after a crash locks again straight away.
Singleton {
    id: root

    property bool locked: false
    readonly property string flag: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/foxtail-locked"

    function lock() {
        Panels.closeAll();
        locked = true;
    }

    onLockedChanged: Quickshell.execDetached(locked ? ["touch", flag] : ["rm", "-f", flag])

    FileView {
        path: root.flag
        blockLoading: true
        printErrors: false
        onLoaded: root.locked = true
    }
}
