import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// "Install Foxtail": a macOS Installer-style assistant. Steps in a sidebar,
// one page at a time, Continue/Go Back at the bottom right. The real work is
// done by `foxtail-install` (as root via pkexec).
FloatingWindow {
    id: win

    title: "Install Foxtail"
    visible: Panels.installer
    onVisibleChanged: if (!visible) Panels.installer = false
    implicitWidth: 720
    implicitHeight: 520
    minimumSize: Qt.size(720, 520)
    color: "transparent"

    readonly property var steps: ["Introduction", "Destination", "Your Account", "Time Zone", "Installation", "Summary"]
    property int step: 0

    // Collected answers
    property var disks: []
    property string disk: ""
    property string fullName: ""
    property string userName: ""
    property string hostName: "foxtail"
    property string password: ""
    property string password2: ""
    property string timezone: "UTC"
    property var timezones: []
    property string tzFilter: ""

    // Install state
    property int pct: 0
    property string message: ""
    property string error: ""
    property bool installing: false

    readonly property bool canContinue: {
        switch (step) {
        case 0: return true;
        case 1: return disk !== "";
        case 2: return /^[a-z_][a-z0-9_-]{0,31}$/.test(userName) && password.length >= 1 && password === password2
                       && /^[A-Za-z0-9-]{1,63}$/.test(hostName);
        case 3: return timezone !== "";
        case 4: return pct >= 100;
        default: return true;
        }
    }

    onFullNameChanged: {
        const auto = fullName.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 32);
        if (!userEdited) userName = auto;
    }
    property bool userEdited: false

    Process {
        running: win.visible
        command: ["lsblk", "-J", "-d", "-b", "-o", "NAME,SIZE,MODEL,TYPE,RM,RO"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.disks = JSON.parse(text).blockdevices
                        .filter(d => d.type === "disk" && !d.ro && d.size > 16e9 && !d.name.startsWith("zram") && !d.name.startsWith("loop"));
                } catch (e) { win.disks = []; }
            }
        }
    }

    Process {
        running: win.visible
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: win.timezones = text.trim().split("\n") }
    }

    Process {
        id: installer
        command: ["pkexec", "env",
                  "FT_DISK=/dev/" + win.disk, "FT_USER=" + win.userName, "FT_FULLNAME=" + win.fullName,
                  "FT_HOST=" + win.hostName, "FT_TZ=" + win.timezone, "/usr/local/bin/foxtail-install"]
        stdinEnabled: true
        onStarted: { write(win.password + "\n"); }
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("PROGRESS ")) {
                    const parts = line.split(" ");
                    win.pct = parseInt(parts[1]);
                    win.message = parts.slice(2).join(" ");
                } else if (line.startsWith("ERROR ")) {
                    win.error = line.slice(6);
                }
            }
        }
        onExited: code => {
            win.installing = false;
            if (code !== 0 && !win.error) win.error = "The installer stopped unexpectedly (code " + code + ").";
            if (code === 0 && win.pct >= 100) win.step = 5;
        }
    }

    function begin() {
        error = "";
        pct = 0;
        message = "Starting…";
        installing = true;
        installer.running = true;
    }

    function human(bytes) {
        const gb = bytes / 1e9;
        return gb >= 1000 ? (gb / 1000).toFixed(1) + " TB" : Math.round(gb) + " GB";
    }

    // ---------------- chrome ----------------
    Rectangle {
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.dark ? "#1E1E1F" : "#FFFFFF"
        border.color: Theme.glassOutline
    }

    MouseArea {
        anchors.fill: parent
        onPressed: { try { win._backingWindow.startSystemMove(); } catch (e) {} }
    }

    Item {
        id: sidebar
        width: 200
        height: parent.height

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: 16
            gradient: Gradient {
                GradientStop { position: 0; color: "#FFB15C" }
                GradientStop { position: 1; color: "#E5400A" }
            }
        }

        TrafficLights {
            x: 22; y: 22
            onClose: if (!win.installing) Panels.installer = false
            onMinimize: Panels.installer = false
        }

        Image {
            x: 30; y: 60
            width: 84; height: 84
            sourceSize: Qt.size(168, 168)
            source: Qt.resolvedUrl("../icons/foxtail.svg")
            opacity: 0.95
        }

        Column {
            x: 26; y: 170
            spacing: 12
            Repeater {
                model: win.steps
                Row {
                    required property string modelData
                    required property int index
                    spacing: 10
                    Rectangle {
                        width: 9; height: 9; radius: 4.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: index <= win.step ? "white" : Qt.rgba(1, 1, 1, 0.35)
                    }
                    Label {
                        text: modelData
                        color: index === win.step ? "white" : Qt.rgba(1, 1, 1, 0.75)
                        font.weight: index === win.step ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    Item {
        id: page
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: buttons.top
        anchors.margins: 28
        anchors.topMargin: 36

        Loader {
            anchors.fill: parent
            sourceComponent: [intro, destination, account, tz, install, summary][win.step]
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 10

        Btn {
            text: "Go Back"
            visible: win.step > 0 && win.step < 4
            onClicked: win.step--
        }
        Btn {
            primary: true
            visible: win.step !== 4 || win.error !== ""
            enabled: win.canContinue || win.error !== ""
            text: win.step === 3 ? "Install" : (win.step === 5 ? "Restart" : (win.error ? "Try Again" : "Continue"))
            onClicked: {
                if (win.step === 5) { Quickshell.execDetached(["systemctl", "reboot"]); return; }
                if (win.step === 4) { win.begin(); return; }
                win.step++;
                if (win.step === 4) win.begin();
            }
        }
    }

    // ---------------- pages ----------------
    Component {
        id: intro
        Column {
            spacing: 14
            Label { text: "Welcome to Foxtail"; font.pixelSize: 26; font.weight: Font.Bold }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                lineHeight: 1.25
                text: "This assistant will install Foxtail on this computer.\n\n" +
                      "You'll choose a disk, create your account, and pick your time zone. " +
                      "Installing takes a few minutes and works without an internet connection.\n\n" +
                      "Important: the disk you choose will be completely erased."
            }
        }
    }

    Component {
        id: destination
        Column {
            spacing: 14
            Label { text: "Select a Destination"; font.pixelSize: 22; font.weight: Font.Bold }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                text: "Choose the disk where you want to install Foxtail. Everything on it will be erased."
                color: Theme.textSecondary
            }
            Flow {
                width: parent.width
                spacing: 14
                Repeater {
                    model: win.disks
                    Rectangle {
                        required property var modelData
                        width: 150; height: 130
                        radius: 12
                        color: win.disk === modelData.name ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                        border.width: win.disk === modelData.name ? 2 : 1
                        border.color: win.disk === modelData.name ? Theme.accent : Theme.separator
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 56; height: 44; radius: 6
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "#D8D8DC" }
                                    GradientStop { position: 1; color: "#A8A8AE" }
                                }
                                Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 8; x: 8; width: 6; height: 6; radius: 3; color: "#4CD964" }
                            }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.model || modelData.name; font.weight: Font.DemiBold; width: 130; horizontalAlignment: Text.AlignHCenter }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: win.human(modelData.size) + " · /dev/" + modelData.name; font.pixelSize: 11; color: Theme.textSecondary }
                        }
                        MouseArea { anchors.fill: parent; onClicked: win.disk = parent.modelData.name }
                    }
                }
            }
            Label {
                visible: win.disks.length === 0
                text: "No suitable disks found (at least 16 GB is required)."
                color: "#FF453A"
            }
        }
    }

    Component {
        id: account
        Column {
            spacing: 12
            Label { text: "Create Your Account"; font.pixelSize: 22; font.weight: Font.Bold }
            Field { label: "Full name"; text: win.fullName; onEdited: t => win.fullName = t }
            Field { label: "Account name"; text: win.userName; onEdited: t => { win.userEdited = true; win.userName = t; } }
            Field { label: "Password"; secret: true; text: win.password; onEdited: t => win.password = t }
            Field { label: "Verify"; secret: true; text: win.password2; onEdited: t => win.password2 = t }
            Field { label: "Computer name"; text: win.hostName; onEdited: t => win.hostName = t }
            Label {
                visible: win.password2 !== "" && win.password !== win.password2
                text: "Passwords don't match."
                color: "#FF453A"
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: tz
        Column {
            spacing: 12
            Label { text: "Select Your Time Zone"; font.pixelSize: 22; font.weight: Font.Bold }
            Field { label: "Search"; text: win.tzFilter; onEdited: t => win.tzFilter = t }
            Rectangle {
                width: parent.width
                height: 250
                radius: 8
                color: "transparent"
                border.color: Theme.separator
                clip: true
                ListView {
                    anchors.fill: parent
                    anchors.margins: 4
                    model: win.timezones.filter(z => z.toLowerCase().indexOf(win.tzFilter.toLowerCase()) >= 0)
                    delegate: Rectangle {
                        required property string modelData
                        width: ListView.view.width
                        height: 26
                        radius: 5
                        color: win.timezone === modelData ? Theme.accent : "transparent"
                        Label {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.replace(/_/g, " ")
                            color: win.timezone === modelData ? "white" : Theme.text
                        }
                        MouseArea { anchors.fill: parent; onClicked: win.timezone = parent.modelData }
                    }
                }
            }
        }
    }

    Component {
        id: install
        Column {
            spacing: 18
            Label { text: win.error ? "Installation Failed" : "Installing Foxtail…"; font.pixelSize: 22; font.weight: Font.Bold }
            Item { width: 1; height: 40 }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 110; height: 110
                sourceSize: Qt.size(220, 220)
                source: Qt.resolvedUrl("../icons/foxtail-logo.png")
                RotationAnimation on rotation {
                    running: win.installing
                    from: 0; to: 360
                    duration: 2400
                    loops: Animation.Infinite
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320; height: 6; radius: 3
                color: Theme.controlOff
                Rectangle {
                    width: parent.width * win.pct / 100
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.error || win.message
                color: win.error ? "#FF453A" : Theme.textSecondary
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
    }

    Component {
        id: summary
        Column {
            spacing: 14
            Label { text: "Foxtail is installed 🎉"; font.pixelSize: 26; font.weight: Font.Bold }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                text: "Remove the installation media, then restart. You'll log in as “" + win.userName + "”."
            }
        }
    }

    // ---------------- widgets ----------------
    component Btn: Rectangle {
        id: b
        property string text
        property bool primary: false
        signal clicked()
        width: Math.max(96, bl.implicitWidth + 28)
        height: 28
        radius: Theme.liquid ? 14 : 7
        opacity: enabled ? 1 : 0.45
        color: primary ? Theme.accent : Theme.control
        Label { id: bl; anchors.centerIn: parent; text: b.text; color: b.primary ? "white" : Theme.text }
        MouseArea { anchors.fill: parent; enabled: b.enabled; onClicked: b.clicked() }
    }

    component Field: Row {
        id: f
        property string label
        property string text
        property bool secret: false
        signal edited(string text)
        spacing: 12
        Label { width: 110; horizontalAlignment: Text.AlignRight; text: f.label; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            width: 260; height: 28; radius: 7
            color: Theme.control
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? Theme.accent : Theme.separator
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                echoMode: f.secret ? TextInput.Password : TextInput.Normal
                text: f.text
                clip: true
                onTextEdited: f.edited(text)
            }
        }
    }
}
