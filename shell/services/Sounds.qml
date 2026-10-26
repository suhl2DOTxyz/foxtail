pragma Singleton
import QtQuick
import Quickshell

// macOS-style interface sounds (freedesktop sound theme, played with
// PipeWire's pw-play): the screenshot shutter, emptying the Trash, volume
// feedback, notifications. Each kind follows its switch in Settings ▸ Sound.
Singleton {
    id: root

    readonly property string dir: "/usr/share/sounds/freedesktop/stereo/"
    readonly property var files: ({
        screenshot: "camera-shutter.oga",
        trash: "trash-empty.oga",
        volume: "audio-volume-change.oga",
        notification: "message-new-instant.oga",
        plug: "power-plug.oga",
        attention: "window-attention.oga"
    })

    function enabled(kind) {
        if (kind === "volume") return Settings.volumeFeedback;
        if (kind === "notification") return Settings.notificationSounds && !Settings.doNotDisturb;
        return Settings.uiSounds;
    }

    // Volume keys repeat: give one click when they settle, like macOS.
    function volumeChanged() { volumeClick.restart(); }
    Timer {
        id: volumeClick
        interval: 180
        onTriggered: root.play("volume")
    }

    // Login chime: once per session (not when the shell restarts).
    function startup() {
        if (!Settings.startupSound) return;
        Quickshell.execDetached(["sh", "-c",
            'f="${XDG_RUNTIME_DIR:-/tmp}/foxtail-chimed"; [ -e "$f" ] && exit 0; touch "$f"; exec pw-play --volume 0.55 /usr/share/sounds/foxtail/startup.wav']);
    }

    signal played(string kind)

    function play(kind) {
        played(kind);
        if (!files[kind] || !enabled(kind)) return;
        Quickshell.execDetached(["pw-play", "--volume", "0.6", dir + files[kind]]);
    }
}
