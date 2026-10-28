import QtQuick
import QtQuick.Effects
import qs.services

// The wallpaper, cropped like the desktop shows it and blurred about as much
// as the compositor blurs it (Theme.glassBlur), as a texture for Liquid Glass to lens. Used by
// glass that only ever sits over the desktop picture (Dock, banners, OSD) and
// as the fallback when popovers don't refract windows.
Item {
    id: root

    property size screenSize: Qt.size(1920, 1080)
    readonly property bool ready: wall.status === Image.Ready
    readonly property Item sharp: sharpTex
    readonly property Item texture: blurred

    // Half resolution: Liquid Glass shows the backdrop nearly sharp at its rim.
    readonly property size texSize: Qt.size(Math.max(1, Math.round(screenSize.width / 2)),
                                            Math.max(1, Math.round(screenSize.height / 2)))

    Item {
        id: box
        width: root.texSize.width
        height: root.texSize.height
        clip: true
        Image {
            id: wall
            anchors.fill: parent
            source: "file://" + Settings.wallpaper
            sourceSize: Qt.size(root.texSize.width * 2, root.texSize.height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    ShaderEffectSource {
        id: sharpTex
        visible: false
        width: box.width
        height: box.height
        sourceItem: box
        hideSource: true
        smooth: true
    }

    MultiEffect {
        id: fx
        width: root.texSize.width
        height: root.texSize.height
        source: sharpTex
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: Math.round(Math.min(64, Theme.glassBlur / 2))
    }

    ShaderEffectSource {
        id: blurred
        visible: false
        width: fx.width
        height: fx.height
        sourceItem: fx
        hideSource: true
        smooth: true
    }
}
