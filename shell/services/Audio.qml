pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.audio !== undefined && sink?.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : true

    // Input (microphone)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: source?.audio !== undefined && source?.audio !== null
    readonly property real inputVolume: sourceReady ? source.audio.volume : 0
    readonly property bool inputMuted: sourceReady ? source.audio.muted : true

    // Hardware devices (not app streams)
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    signal changedByUser()

    function setVolume(v) {
        if (!ready) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        changedByUser();
    }

    function toggleMute() {
        if (ready) sink.audio.muted = !sink.audio.muted;
        changedByUser();
    }

    function setInputVolume(v) {
        if (!sourceReady) return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function setSink(node) { Pipewire.preferredDefaultAudioSink = node; }
    function setSource(node) { Pipewire.preferredDefaultAudioSource = node; }

    // Friendly device name and icon.
    function deviceName(n) {
        return n?.description || n?.nickname || n?.name || "Unknown";
    }
    function deviceIcon(n) {
        const s = ((n?.name ?? "") + " " + (n?.description ?? "")).toLowerCase();
        if (s.indexOf("bluez") >= 0 || s.indexOf("headphone") >= 0 || s.indexOf("headset") >= 0) return "headphones";
        if (s.indexOf("hdmi") >= 0 || s.indexOf("displayport") >= 0) return "display";
        if (!n?.isSink) return "mic";
        return "speaker";
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
}
