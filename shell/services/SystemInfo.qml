pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Static facts for "About This Foxtail" and System Settings → General → About.
Singleton {
    id: root

    property string version: ""
    readonly property string codename: "Vixen"
    property string cpu: ""
    property string memory: ""
    property string gpu: ""
    property string kernel: ""
    property string hostname: ""
    property string user: Quickshell.env("USER") ?? ""
    property string fullName: ""
    property string disk: ""
    property string machine: ""
    property string timezone: ""

    function run(cmd, cb) {
        const p = runner.createObject(root, { command: cmd });
        p.done.connect(t => { cb(t.trim()); p.destroy(); });
        p.running = true;
    }

    Component {
        id: runner
        Process {
            id: proc
            signal done(string text)
            stdout: StdioCollector { onStreamFinished: proc.done(text) }
        }
    }

    Component.onCompleted: {
        run(["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"], t => cpu = t);
        run(["sh", "-c", "awk '/MemTotal/ {printf \"%.0f GB\", $2/1024/1024}' /proc/meminfo"], t => memory = t);
        run(["sh", "-c", "lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3"], t => gpu = t || "Unknown");
        run(["sh", "-c", ". /etc/os-release; echo \"$VERSION_ID\""], t => version = t);
        run(["uname", "-r"], t => kernel = t);
        run(["cat", "/etc/hostname"], t => hostname = t);
        run(["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"], t => fullName = t || user);
        run(["sh", "-c", "df -h / | awk 'NR==2 {print $4 \" available of \" $2}'"], t => disk = t);
        run(["sh", "-c", "cat /sys/class/dmi/id/product_name 2>/dev/null || echo Computer"], t => machine = t);
        run(["sh", "-c", "readlink /etc/localtime | sed 's|.*/zoneinfo/||'"], t => timezone = t);
    }
}
