pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Display brightness through brightnessctl. In a VM there is usually no
// backlight, in which case `available` stays false and the slider hides.
Singleton {
    id: root

    property bool available: false
    property real value: 1.0
    property int max: 1

    signal changedByUser()

    function set(v) {
        value = Math.max(0.02, Math.min(1, v));
        setter.command = ["brightnessctl", "-q", "set", Math.round(value * 100) + "%"];
        setter.running = true;
        changedByUser();
    }

    Process {
        id: probe
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const f = text.trim().split(",");
                if (f.length >= 5) {
                    root.available = true;
                    root.max = parseInt(f[4]);
                    root.value = parseInt(f[2]) / root.max;
                }
            }
        }
    }

    Process { id: setter }
}
