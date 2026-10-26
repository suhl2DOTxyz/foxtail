import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Hot Corners (System Settings ▸ Desktop & Dock): pushing the pointer into a
// screen corner starts an action, as on macOS.
Scope {
    id: root

    required property var modelData

    // Something a corner opened is still showing.
    readonly property bool busy: Panels.missionControl || Panels.launchpad || Panels.popover !== "" || Lock.locked

    function run(action) {
        switch (action) {
        case "mission": Panels.popover = ""; Panels.missionControl = !Panels.missionControl; break;
        case "desktop": Hypr.showDesktop(); break;
        case "notifications": Panels.toggle("calendar", root.modelData); break;
        case "launchpad": Panels.closeAll(); Panels.launchpad = true; break;
        case "lock": Lock.lock(); break;
        case "sleep": Hypr.dispatch(`hl.dsp.dpms({ action = "off" })`); break;
        }
    }

    Variants {
        model: ["tl", "tr", "bl", "br"]

        PanelWindow {
            id: corner
            required property string modelData
            readonly property string action: Settings.hotCorners[modelData] ?? ""
            screen: root.modelData
            visible: action !== ""

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "foxtail-hotcorner"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: corner.modelData[0] === "t"
                bottom: corner.modelData[0] === "b"
                left: corner.modelData[1] === "l"
                right: corner.modelData[1] === "r"
            }
            implicitWidth: 4
            implicitHeight: 4
            color: "transparent"

            // Fires once per visit: the pointer has to leave the corner before
            // it can trigger again (closing Mission Control with the pointer
            // still in the corner mustn't reopen it).
            property bool armed: true
            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        if (corner.armed) dwell.restart();
                    } else {
                        dwell.stop();
                        if (!root.busy) corner.armed = true;
                    }
                }
            }
            // A brief pause, so brushing past the corner doesn't trigger it.
            Timer {
                id: dwell
                interval: 120
                onTriggered: {
                    corner.armed = false;
                    root.run(corner.action);
                }
            }
        }
    }
}
