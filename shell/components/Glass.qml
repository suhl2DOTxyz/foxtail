import QtQuick
import QtQuick.Effects
import qs.services

// The Foxtail material. Two looks, switched live by Settings.liquidGlass:
//
//  classic  - macOS "vibrancy": milky translucent fill over the compositor's
//             blur, hairline highlight inside, dark outline outside.
//  liquid   - shaders/liquidglass.frag: a clear slab whose rim refracts the
//             wallpaper, with chromatic fringing and a specular edge.
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
    property real bezel: Math.min(26, Math.min(width, height) * 0.42)
    property real refraction: Math.min(28, bezel * 1.1)
    property real dispersion: 0.8
    property real frost: 2.0
    // How opaque the refracted rim gets. The shader can only refract the
    // wallpaper, so surfaces that float over windows keep this lower.
    property real rimOpacity: 0.97
    // Brightness of the backdrop as seen by the viewer; lower it when the
    // surface sits on a dimmed scrim so the rim matches its surroundings.
    property real exposure: 1.0
    property real rimLight: Theme.dark ? 0.75 : 1.0

    // Key light, in item coordinates (0..1; may sit outside the item). Owners
    // can feed the pointer position into `pointer` to make the highlight
    // follow the cursor; it eases back to the key light when cleared.
    property point keyLight: Qt.point(0.18, -0.9)
    property point pointer: Qt.point(-1, -1)
    readonly property bool tracking: pointer.x >= 0
    property real lightX: tracking ? pointer.x : keyLight.x
    property real lightY: tracking ? Math.min(pointer.y, -0.4) : keyLight.y
    Behavior on lightX { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on lightY { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // Where this item sits on screen, so the shader can sample the matching
    // part of the wallpaper. Owners pass the window's offset on screen.
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
        color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.18 : 0.12) * root.shadowStrength * (root.liquid ? 0.7 : 1.0))
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
    Image {
        id: wallTex
        visible: false
        source: root.liquid ? "file://" + Settings.wallpaper : ""
        sourceSize: Qt.size(root.screenSize.width / 2, root.screenSize.height / 2)
        fillMode: Image.PreserveAspectCrop
        width: root.screenSize.width
        height: root.screenSize.height
        asynchronous: true
        cache: true
    }

    ShaderEffect {
        visible: root.liquid && wallTex.status === Image.Ready
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/liquidglass.frag.qsb")

        property var backdrop: wallTex
        property size itemSize: Qt.size(width, height)
        property rect screenRect: Qt.rect(root.screenPos.x / root.screenSize.width,
                                          root.screenPos.y / root.screenSize.height,
                                          width / root.screenSize.width,
                                          height / root.screenSize.height)
        property real radius: root.radius
        property real bezel: root.bezel
        property real refraction: root.refraction
        property real dispersion: root.dispersion
        property real frost: root.frost
        property vector4d tint: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)
        property real rimLight: root.rimLight
        property real dark: Theme.dark ? 1 : 0
        property point light: Qt.point(root.lightX, root.lightY)
        property real rimOpacity: root.rimOpacity
        property real exposure: root.exposure
    }

    // Fallback while the wallpaper texture loads.
    Rectangle {
        visible: root.liquid && wallTex.status !== Image.Ready
        anchors.fill: parent
        radius: root.radius
        color: Theme.glassStrong
    }
}
