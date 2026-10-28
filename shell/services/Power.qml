pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery and power modes. Wraps UPower's display device and
// power-profiles-daemon, and posts low-battery warnings like macOS.
Singleton {
    id: root

    // The lid: while the shell runs, it takes the lid switch over from logind
    // so closing the lid can do what System Settings says (and turn off just
    // the built-in display when an external one is connected, like macOS).
    // Hyprland reports the switch to foxtail-lid. If the shell stops, the
    // inhibitor goes with it and logind's default (sleep) applies again.
    Process {
        running: root.hasBattery
        command: ["systemd-inhibit", "--what=handle-lid-switch", "--who=Foxtail",
                  "--why=Foxtail handles the lid (System Settings > Battery)", "--mode=block",
                  "sleep", "infinity"]
    }

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device?.isLaptopBattery ?? false
    readonly property real percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onAc: !UPower.onBattery

    // "3:42 remaining" / "1:05 until full" / "" when unknown
    readonly property string timeLeft: {
        const secs = charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0);
        if (!secs || secs <= 0 || full) return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return `${h}:${String(m).padStart(2, "0")} ${charging ? I18n.tr("until full") : I18n.tr("remaining")}`;
    }

    readonly property string source: full ? I18n.tr("Fully Charged") : charging ? I18n.tr("Charging") : onAc ? I18n.tr("Power Adapter") : I18n.tr("Battery")

    // "power-saver" | "balanced" | "performance"
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property string mode: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
                                  : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    function setMode(m) {
        PowerProfiles.profile = m === "power-saver" ? PowerProfile.PowerSaver
                              : m === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }

    // ---- low-battery warnings (once per threshold per discharge) ----
    property int warnedAt: 101
    onPercentChanged: {
        if (!hasBattery) return;
        if (charging || onAc) { warnedAt = 101; return; }
        for (const t of [20, 10, 5]) {
            if (percent <= t && warnedAt > t) {
                warnedAt = t;
                Quickshell.execDetached(["notify-send", "-a", "Battery", "-i", "battery-caution",
                    "-u", t <= 10 ? "critical" : "normal",
                    t <= 5 ? "Your battery is critically low" : "Low Battery",
                    `${percent}% remaining. ` + (t <= 10 ? "Plug in your computer soon." : "Consider switching to Low Power mode.")]);
                if (t === 10 && Settings.autoLowPower && mode !== "power-saver") setMode("power-saver");
                break;
            }
        }
    }
}
