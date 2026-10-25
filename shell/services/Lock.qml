pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool locked: false

    function lock() {
        Panels.closeAll();
        locked = true;
    }
}
