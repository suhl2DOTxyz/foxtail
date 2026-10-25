import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The Dock. Pinned apps, then running apps that aren't pinned, then Trash.
// Hover magnification follows the pointer like macOS's; launching bounces the
// icon until the app's first window appears; a dot marks running apps.
PanelWindow {
    id: dock

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "foxtail-dock"
    exclusionMode: ExclusionMode.Normal
    anchors { bottom: true; left: true; right: true }
    color: "transparent"

    readonly property real iconSize: Settings.dockIconSize
    readonly property real magnify: Settings.dockMagnification ? Settings.dockMagnifySize : 1.0
    readonly property real pad: Math.round(iconSize * 0.14)
    readonly property real spacing: Math.round(iconSize * 0.08)
    readonly property real bottomGap: 6
    readonly property real bodyHeight: iconSize + pad * 2

    implicitHeight: iconSize * magnify + pad * 2 + bottomGap + 40
    exclusiveZone: Settings.dockAutoHide ? 0 : bodyHeight + bottomGap

    readonly property bool hovered: hover.hovered
    readonly property bool shown: !Settings.dockAutoHide || hovered || Panels.popover === "dockmenu"

    // Input only where the Dock actually is; the rest of the strip passes through.
    mask: Region { item: hitArea }

    Item {
        id: hitArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: body.width
        height: !dock.shown ? 4 : (dock.hovered ? dock.height : dock.bodyHeight + dock.bottomGap)
        HoverHandler { id: hover }
    }

    // ---- model ----
    readonly property var items: {
        const out = [];
        const pinned = Settings.pinnedApps;
        for (let i = 0; i < pinned.length; i++) {
            out.push({ kind: "app", id: pinned[i] });
            if (i === 0) out.push({ kind: "launchpad", id: "launchpad" });
        }
        if (Apps.unpinnedRunning.length) {
            out.push({ kind: "sep", id: "sep1" });
            for (const id of Apps.unpinnedRunning) out.push({ kind: "app", id });
        }
        out.push({ kind: "sep", id: "sep2" });
        // Minimized windows sit between the separator and Trash, as on macOS.
        for (const t of Hypr.minimized)
            out.push({ kind: "min", id: "min:" + t.address, toplevel: t });
        out.push({ kind: "trash", id: "trash" });
        return out;
    }

    // Un-magnified centers, used to compute magnification without feedback.
    readonly property var baseCenters: {
        const c = [];
        let x = pad;
        for (const it of items) {
            const w = it.kind === "sep" ? 13 : iconSize;
            c.push(x + w / 2);
            x += w + spacing;
        }
        return c;
    }
    readonly property real baseWidth: {
        let x = pad * 2 - spacing;
        for (const it of items) x += (it.kind === "sep" ? 13 : iconSize) + spacing;
        return x;
    }

    property real pointerX: -1000  // in base coordinates

    function scaleAt(i) {
        if (!hovered || magnify <= 1.0) return 1.0;
        const d = Math.abs(pointerX - baseCenters[i]);
        const range = iconSize * 2.6;
        if (d >= range) return 1.0;
        return 1.0 + (magnify - 1.0) * (Math.cos(Math.PI * d / range) + 1) / 2;
    }

    // ---- body ----
    Item {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        width: row.width + dock.pad * 2
        height: dock.bodyHeight
        y: dock.height - height - dock.bottomGap + (dock.shown ? 0 : dock.bodyHeight + dock.bottomGap + 4)
        Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Glass {
            id: dockGlass
            anchors.fill: parent
            radius: Theme.liquid ? Math.round(dock.bodyHeight * 0.42) : 18
            // The highlight slides along the Dock with the pointer.
            pointer: dockHover.hovered ? Qt.point(dockHover.point.position.x / width, -0.6) : Qt.point(-1, -1)
            screenSize: Qt.size(dock.width, dock.screen.height)
            windowOffset: Qt.point(0, dock.screen.height - dock.height)
            bezel: 26
            refraction: 26
        }

        HoverHandler {
            id: dockHover
            target: null
            onPointChanged: {
                // Map pointer back to base (un-magnified) coordinates.
                const px = point.position.x;
                dock.pointerX = px / body.width * dock.baseWidth;
            }
        }
    }

    Row {
        id: row
        anchors.bottom: body.bottom
        anchors.bottomMargin: dock.pad
        anchors.horizontalCenter: body.horizontalCenter
        spacing: dock.spacing

        Repeater {
            model: dock.items

            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property real s: modelData.kind === "sep" ? 1.0 : dock.scaleAt(index)
                readonly property bool running: modelData.kind === "app" && Apps.isRunning(modelData.id)

                width: modelData.kind === "sep" ? 13 : dock.iconSize * s
                height: dock.iconSize
                Behavior on width { enabled: !dock.hovered; NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

                // Separator
                Rectangle {
                    visible: cell.modelData.kind === "sep"
                    anchors.centerIn: parent
                    width: 1
                    height: dock.iconSize * 0.8
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.18)
                }

                Item {
                    id: iconBox
                    visible: cell.modelData.kind !== "sep"
                    width: dock.iconSize * cell.s
                    height: width
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    property real bounce: 0
                    transform: Translate { y: -iconBox.bounce }

                    // Minimized window: a small "window" card carrying the app icon.
                    Rectangle {
                        visible: cell.modelData.kind === "min"
                        anchors.fill: parent
                        anchors.margins: parent.width * 0.08
                        radius: width * 0.16
                        color: Theme.dark ? "#2C2C2E" : "#FFFFFF"
                        border.color: Theme.separator
                        Rectangle {   // title bar strip with traffic lights
                            width: parent.width; height: parent.height * 0.18
                            radius: parent.radius
                            color: Theme.dark ? "#3A3A3C" : "#ECECEE"
                            Row {
                                x: parent.width * 0.1
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: parent.height * 0.25
                                Repeater {
                                    model: ["#FF5F57", "#FEBC2E", "#28C840"]
                                    Rectangle { required property string modelData; width: parent.parent.height * 0.42; height: width; radius: width / 2; color: modelData }
                                }
                            }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: cell.modelData.kind === "min" ? parent.width * 0.26 : 0
                        anchors.topMargin: cell.modelData.kind === "min" ? parent.width * 0.32 : 0
                        visible: cell.modelData.kind !== "launchpad"
                        sourceSize: Qt.size(dock.iconSize * dock.magnify * 2, dock.iconSize * dock.magnify * 2)
                        smooth: true
                        mipmap: true
                        source: cell.modelData.kind === "trash"
                            ? Quickshell.iconPath("user-trash", "user-trash-full")
                            : cell.modelData.kind === "min"
                                ? Apps.iconFor(Apps.idForToplevel(cell.modelData.toplevel.wayland))
                                : Apps.iconFor(cell.modelData.id)
                        opacity: press.pressed ? 0.7 : 1
                    }

                    // Launchpad tile drawn in QML: a glass rounded square with a grid of dots.
                    Rectangle {
                        visible: cell.modelData.kind === "launchpad"
                        anchors.fill: parent
                        anchors.margins: parent.width * 0.06
                        radius: width * 0.23
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#FFB15C" }
                            GradientStop { position: 1; color: "#E5400A" }
                        }
                        Grid {
                            anchors.centerIn: parent
                            columns: 3
                            spacing: parent.width * 0.08
                            Repeater {
                                model: 9
                                Rectangle {
                                    width: iconBox.width * 0.14
                                    height: width
                                    radius: width * 0.3
                                    color: Qt.rgba(1, 1, 1, 0.92)
                                }
                            }
                        }
                    }

                    SequentialAnimation {
                        id: bounceAnim
                        loops: 3
                        NumberAnimation { target: iconBox; property: "bounce"; to: dock.iconSize * 0.45; duration: 260; easing.type: Easing.OutQuad }
                        NumberAnimation { target: iconBox; property: "bounce"; to: 0; duration: 260; easing.type: Easing.InQuad }
                    }
                }

                // Running indicator
                Rectangle {
                    visible: cell.running
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: Math.max(1, dock.pad / 2 - 2)
                    width: 4; height: 4; radius: 2
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.7)
                }

                // Tooltip
                Rectangle {
                    id: tip
                    visible: press.containsMouse && cell.modelData.kind !== "sep" && Panels.popover !== "dockmenu"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: iconBox.top
                    anchors.bottomMargin: 12
                    width: tipLabel.implicitWidth + 22
                    height: 26
                    radius: Theme.liquid ? 13 : 6
                    color: Theme.glassStrong
                    border.color: Theme.glassOutline
                    Label {
                        id: tipLabel
                        anchors.centerIn: parent
                        text: cell.modelData.kind === "trash" ? "Trash"
                            : cell.modelData.kind === "launchpad" ? "Launchpad"
                            : cell.modelData.kind === "min" ? (cell.modelData.toplevel.title || "Window")
                            : Apps.nameFor(cell.modelData.id)
                    }
                }

                MouseArea {
                    id: press
                    anchors.fill: parent
                    enabled: cell.modelData.kind !== "sep"
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        const it = cell.modelData;
                        if (m.button === Qt.RightButton && it.kind === "app") {
                            const p = cell.mapToItem(null, cell.width / 2, 0);
                            Panels.dockMenuApp = it.id;
                            Panels.dockMenuX = p.x;
                            Panels.toggle("dockmenu", dock.modelData);
                            return;
                        }
                        Panels.closeAll();
                        if (it.kind === "launchpad") {
                            Panels.launchpad = true;
                        } else if (it.kind === "min") {
                            Hypr.restore(it.toplevel);
                        } else if (it.kind === "trash") {
                            Quickshell.execDetached(["nautilus", "trash:///"]);
                        } else if (!Apps.activate(it.id) && it.id !== "foxtail-settings") {
                            bounceAnim.restart();
                        }
                    }
                }

                Connections {
                    target: Apps
                    function onToplevelsChanged() {
                        if (cell.running && bounceAnim.running) {
                            bounceAnim.stop();
                            iconBox.bounce = 0;
                        }
                    }
                }
            }
        }
    }
}
