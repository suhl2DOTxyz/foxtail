pragma Singleton
import QtQuick
import Quickshell

// Which transient surfaces are open. Only one popover is open at a time, the
// way macOS closes a menu when you open Control Center.
Singleton {
    id: root

    // "" | "fox" | "app:<index>" | "controlcenter" | "calendar" | "wifi" | "dockmenu"
    property string popover: ""
    property bool spotlight: false
    property bool launchpad: false
    property bool settings: false
    property bool about: false
    property bool forceQuit: false
    property bool installer: false
    property bool missionControl: false
    property bool screenshotBar: false
    property string settingsPane: "appearance"
    // Pending power confirmation: "" | "restart" | "shutdown" | "logout"
    property string confirm: ""

    // Dock context menu payload
    property var dockMenuApp: null
    property real dockMenuX: 0

    // Horizontal extent of the menu-bar item a popover hangs from.
    property real anchorX: 0
    property real anchorRight: 0

    // Screen the popover belongs to
    property var screen: null

    readonly property bool anyOverlay: popover !== "" || spotlight

    function toggle(name, scr) {
        spotlight = false;
        if (popover === name) {
            popover = "";
        } else {
            popover = name;
            screen = scr ?? screen;
        }
    }

    function closeAll() {
        popover = "";
        spotlight = false;
        launchpad = false;
        missionControl = false;
    }

    function openSettings(pane) {
        closeAll();
        if (pane) settingsPane = pane;
        settings = true;
    }
}
