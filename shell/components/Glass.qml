import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services

// The Foxtail material. Two looks, switched live by Settings.liquidGlass:
//
//  classic  - macOS "vibrancy": milky translucent fill over the compositor's
//             blur, hairline highlight inside, dark outline outside.
//  liquid   - shaders/liquidglass.frag: frosted glass whose rim lenses what
//             is behind it, with a thin specular sheen and a tint that adapts
//             to the content underneath.
//
// Hyprland blurs whatever is behind any non-transparent pixel of a Foxtail
// layer surface (see hypr/foxtail.lua), so both looks get real backdrop blur.
Item {
    id: root

    property real radius: Theme.radiusLarge
    property color color: Theme.glass
    property bool liquid: Theme.liquid
    property bool shadow: true
    property real shadowStrength: 1.0
    property bool outline: true

    // Liquid tuning
    // Width of the curved rim, and how tall the dome over it is (bigger glass
    // is "thicker", as Apple puts it: deeper lensing, softer light).
    property real bezel: Math.min(22, Math.min(width, height) * 0.36)
    property real thickness: 1.6
    // How far, at most, the rim reaches inward for what it shows (px). Kept
    // modest: macOS 27 made refraction gentler and more uniform than Tahoe's.
    property real refraction: Math.min(9, bezel * 0.45)
    property real dispersion: 0.5
    // How clear the lens is right at the lip (it frosts toward the middle).
    // More tint (the Appearance slider) makes it frostier.
    property real clarity: 0.85 - 0.45 * Settings.glassTintLevel
    // How strongly the lensed rim covers the compositor's live blur.
    property real rimOpacity: 0.9
    // Brightness of the backdrop as seen by the viewer; lower it when the
    // surface sits on a dimmed scrim so the rim matches its surroundings.
    property real exposure: 1.0
    property real rimLight: Theme.dark ? 0.8 : 1.0
    // Raise the tint where the content behind would make text hard to read.
    property real adapt: 1.0

    // Apple's glass "materializes" - its lensing and light ramp in - instead
    // of simply fading. Popovers are created when they open, so this runs on
    // every appearance.
    property bool animateIn: true
    property real materialize: animateIn ? 0 : 1
    NumberAnimation on materialize {
        running: root.animateIn
        from: 0; to: 1
        duration: Theme.ms(420)
        easing.type: Easing.OutCubic
    }

    // "Illuminate from within" on press: owners set `pressed` (and, for a
    // pointer, `pressPoint` in item coordinates 0..1).
    property bool pressed: false
    property point pressPoint: Qt.point(0.5, 0.5)
    property real glow: pressed ? 1 : 0
    Behavior on glow { NumberAnimation { duration: root.pressed ? 260 : 520; easing.type: Easing.OutCubic } }

    // Key light, in item coordinates (0..1; may sit outside the item). Owners
    // can feed the pointer position into `pointer` to make the highlight
    // follow the cursor; it eases back to the key light when cleared.
    property point keyLight: Qt.point(0.12, -0.6)
    property point pointer: Qt.point(-1, -1)
    readonly property bool tracking: pointer.x >= 0
    property real lightX: tracking ? pointer.x : keyLight.x
    property real lightY: tracking ? Math.min(pointer.y, -0.4) : keyLight.y
    Behavior on lightX { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
    Behavior on lightY { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }

    // Where this item sits on screen, so the shader can sample the matching
    // part of the backdrop. Owners pass the window's offset on screen.
    property point windowOffset: Qt.point(0, 0)
    property size screenSize: Qt.size(1920, 1080)
    readonly property point screenPos: {
        // Touch geometry so this re-evaluates when we or our ancestors move.
        void [x, y, width, height, parent?.x, parent?.y, parent?.parent?.x, parent?.parent?.y];
        const p = mapToItem(null, 0, 0);
        return Qt.point(p.x + windowOffset.x, p.y + windowOffset.y);
    }

    RectangularShadow {
        visible: root.shadow && !Settings.reduceTransparency
        anchors.fill: parent
        radius: root.radius
        offset.y: 8 * root.shadowStrength
        blur: 36 * root.shadowStrength
        spread: -4
        color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.18 : 0.12) * root.shadowStrength * (root.liquid ? 0.75 : 1.0))
    }

    // ---- classic vibrancy ----
    Rectangle {
        visible: !root.liquid
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.width: root.outline ? 1 : 0
        border.color: Theme.glassOutline

        Rectangle {
            visible: root.outline
            anchors.fill: parent
            anchors.margins: 1
            radius: root.radius - 1
            color: "transparent"
            border.width: 1
            border.color: Theme.glassBorder
            opacity: 0.7
        }
    }

    // ---- liquid glass ----
    // The window's shared blurred backdrop (popovers: a live screen snapshot,
    // windows included); otherwise our own blurred copy of the wallpaper.
    readonly property var shared: QsWindow.window?.backdrop ?? null
    readonly property bool useShared: shared !== null && shared.ready
    Loader {
        id: own
        active: root.liquid && !root.useShared
        sourceComponent: WallpaperBackdrop { screenSize: root.screenSize }
    }
    readonly property var backdropItem: useShared ? shared : (own.item?.ready ? own.item : null)
    readonly property var source: backdropItem?.texture ?? null

    ShaderEffect {
        visible: root.liquid && root.source !== null
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/liquidglass.frag.qsb")

        property var backdrop: root.backdropItem?.sharp ?? root.source
        property var blurred: root.source
        property size itemSize: Qt.size(width, height)
        property rect screenRect: Qt.rect(root.screenPos.x / root.screenSize.width,
                                          root.screenPos.y / root.screenSize.height,
                                          width / root.screenSize.width,
                                          height / root.screenSize.height)
        property real radius: root.radius
        property real bezel: root.bezel
        property real thickness: root.thickness
        property real refraction: root.refraction
        property real dispersion: root.dispersion
        property vector4d tint: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)
        property real rimLight: root.rimLight
        property real dark: Theme.dark ? 1 : 0
        property point light: Qt.point(root.lightX, root.lightY)
        property real rimOpacity: root.rimOpacity
        property real exposure: root.exposure
        property real adapt: root.adapt
        property real contrast: Settings.glassTintLevel
        property real materialize: root.materialize
        property real clarity: root.clarity
        property vector3d press: Qt.vector3d(root.pressPoint.x, root.pressPoint.y, root.glow)
    }

    // Until the backdrop is ready: a plain frosted fill.
    Rectangle {
        visible: root.liquid && root.source === null
        anchors.fill: parent
        radius: root.radius
        color: Theme.glassStrong
    }
}
