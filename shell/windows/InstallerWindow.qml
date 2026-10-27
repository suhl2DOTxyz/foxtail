import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.settings

// "Install Foxtail": a macOS Installer-style assistant. Steps in a sidebar,
// one page at a time, Continue/Go Back at the bottom right. The real work is
// done by `foxtail-install` (as root via pkexec).
FloatingWindow {
    id: win

    title: I18n.tr("Install Foxtail")
    visible: Panels.installer
    onVisibleChanged: if (!visible) Panels.installer = false
    implicitWidth: 720
    implicitHeight: 520
    minimumSize: Qt.size(720, 520)
    color: "transparent"

    readonly property var steps: ["Introduction", "Language", "Destination", "Your Account", "Time Zone", "Installation", "Summary"]
    property int step: 0

    // Collected answers
    property var disks: []
    property string disk: ""
    // Largest free region per disk, in bytes ({ sda: 42e9 }), and whether
    // the disk already has an EFI partition (needed to install alongside).
    property var freeSpace: ({})
    property var hasEsp: ({})
    property string mode: "erase"          // "erase" | "alongside"
    property bool encrypt: false

    property string locale: "en_US.UTF-8"
    property string keymap: "us"
    property var layouts: []               // [[code, description]]
    property string layoutFilter: ""
    readonly property var languages: [
        ["en_US.UTF-8", "English (US)"], ["en_GB.UTF-8", "English (UK)"], ["de_DE.UTF-8", "Deutsch"],
        ["fr_FR.UTF-8", "Français"], ["es_ES.UTF-8", "Español"], ["it_IT.UTF-8", "Italiano"],
        ["pt_BR.UTF-8", "Português (Brasil)"], ["pt_PT.UTF-8", "Português"], ["nl_NL.UTF-8", "Nederlands"],
        ["pl_PL.UTF-8", "Polski"], ["sv_SE.UTF-8", "Svenska"], ["tr_TR.UTF-8", "Türkçe"],
        ["uk_UA.UTF-8", "Українська"], ["ru_RU.UTF-8", "Русский"], ["ja_JP.UTF-8", "日本語"],
        ["ko_KR.UTF-8", "한국어"], ["zh_CN.UTF-8", "简体中文"], ["zh_TW.UTF-8", "繁體中文"]
    ]
    // A sensible keyboard for each language (the user can still change it).
    readonly property var defaultLayout: ({
        "en_GB.UTF-8": "gb", "de_DE.UTF-8": "de", "fr_FR.UTF-8": "fr", "es_ES.UTF-8": "es",
        "it_IT.UTF-8": "it", "pt_BR.UTF-8": "br", "pt_PT.UTF-8": "pt", "nl_NL.UTF-8": "us",
        "pl_PL.UTF-8": "pl", "sv_SE.UTF-8": "se", "tr_TR.UTF-8": "tr", "uk_UA.UTF-8": "ua",
        "ru_RU.UTF-8": "ru", "ja_JP.UTF-8": "jp", "ko_KR.UTF-8": "kr"
    })

    // Apply the layout to the live session right away, so the password typed
    // in "Your Account" uses the same keys as the installed system.
    onKeymapChanged: Quickshell.execDetached(["hyprctl", "eval", `hl.config({ input = { kb_layout = "${keymap}" } })`])
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
        case 1: return locale !== "" && keymap !== "";
        case 2: return disk !== "" && (mode === "erase" || (freeSpace[disk] ?? 0) >= 20e9);
        case 3: return /^[a-z_][a-z0-9_-]{0,31}$/.test(userName) && password.length >= 1 && password === password2
                       && /^[A-Za-z0-9-]{1,63}$/.test(hostName);
        case 4: return timezone !== "";
        case 5: return pct >= 100;
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
                spaceProbe.running = true;
            }
        }
    }

    // Free space and existing EFI partitions, for "install alongside".
    // (The live session can sudo without a password.)
    Process {
        id: spaceProbe
        command: ["sh", "-c", "for d in $(lsblk -dno NAME -e 7,11,251,252); do " +
                  "f=$(sudo -n sfdisk --list-free --bytes /dev/$d 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $4}' | sort -n | tail -1); " +
                  "e=$(lsblk -no PARTTYPE /dev/$d | grep -ci c12a7328-f81f-11d2-ba4b-00a0c93ec93b); " +
                  "echo \"$d ${f:-0} $e\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const free = {}, esp = {};
                for (const l of text.trim().split("\n")) {
                    const [d, f, e] = l.split(" ");
                    if (!d) continue;
                    free[d] = Number(f) || 0;
                    esp[d] = Number(e) > 0;
                }
                win.freeSpace = free;
                win.hasEsp = esp;
            }
        }
    }

    // Keyboard layouts from xkeyboard-config.
    Process {
        running: win.visible
        command: ["sh", "-c", "awk '/^! layout/{f=1;next} /^!/{f=0} f && NF {c=$1; $1=\"\"; sub(/^ +/,\"\"); print c \"\\t\" $0}' /usr/share/X11/xkb/rules/base.lst"]
        stdout: StdioCollector {
            onStreamFinished: win.layouts = text.trim().split("\n").map(l => l.split("\t")).filter(x => x.length === 2)
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
                  "FT_HOST=" + win.hostName, "FT_TZ=" + win.timezone, "FT_LOCALE=" + win.locale,
                  "FT_KEYMAP=" + win.keymap, "FT_MODE=" + win.mode, "FT_ENCRYPT=" + (win.encrypt ? "1" : "0"),
                  "/usr/bin/foxtail-install"]
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
            if (code === 0 && win.pct >= 100) win.step = 6;
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
            sourceComponent: [intro, language, destination, account, tz, install, summary][win.step]
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 10

        Btn {
            text: I18n.tr("Go Back")
            visible: win.step > 0 && win.step < 5
            onClicked: win.step--
        }
        Btn {
            primary: true
            visible: win.step !== 5 || win.error !== ""
            enabled: win.canContinue || win.error !== ""
            text: win.step === 4 ? "Install" : (win.step === 6 ? "Restart" : (win.error ? "Try Again" : "Continue"))
            onClicked: {
                if (win.step === 6) { Quickshell.execDetached(["systemctl", "reboot"]); return; }
                if (win.step === 5) { win.begin(); return; }
                win.step++;
                if (win.step === 5) win.begin();
            }
        }
    }

    // ---------------- pages ----------------
    Component {
        id: intro
        Column {
            spacing: 14
            Label { text: I18n.tr("Welcome to Foxtail"); font.pixelSize: Theme.px(26); font.weight: Font.Bold }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                lineHeight: 1.25
                text: I18n.tr("This assistant will install Foxtail on this computer.\n\n") +
                      "You'll choose a disk, create your account, and pick your time zone. " +
                      "Installing takes a few minutes and works without an internet connection.\n\n" +
                      "You can erase a disk, or install alongside another system (such as Windows) if there's free space on it."
            }
        }
    }

    Component {
        id: destination
        Column {
            spacing: 14
            Label { text: I18n.tr("Select a Destination"); font.pixelSize: Theme.px(22); font.weight: Font.Bold }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                text: I18n.tr("Choose the disk where you want to install Foxtail.")
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
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: win.human(modelData.size) + " · /dev/" + modelData.name; font.pixelSize: Theme.px(11); color: Theme.textSecondary }
                        }
                        MouseArea { anchors.fill: parent; onClicked: win.disk = parent.modelData.name }
                    }
                }
            }
            Label {
                visible: win.disks.length === 0
                text: I18n.tr("No suitable disks found (at least 16 GB is required).")
                color: "#FF453A"
            }

            Column {
                visible: win.disk !== ""
                width: parent.width
                spacing: 8
                readonly property real free: win.freeSpace[win.disk] ?? 0
                readonly property bool canAlongside: free >= 20e9 && (win.hasEsp[win.disk] ?? false)
                onCanAlongsideChanged: if (!canAlongside) win.mode = "erase"

                Choice {
                    selected: win.mode === "erase"
                    title: I18n.tr("Erase disk and install Foxtail")
                    sub: I18n.tr("Everything on /dev/") + win.disk + " will be deleted."
                    onPicked: win.mode = "erase"
                }
                Choice {
                    enabled: parent.canAlongside
                    selected: win.mode === "alongside"
                    title: I18n.tr("Install alongside the existing system")
                    sub: parent.canAlongside
                        ? `Uses ${win.human(parent.free)} of free space. Your other system and files stay untouched, and you choose which one to start when the computer turns on.`
                        : "Needs at least 20 GB of unpartitioned space and an existing EFI system. Shrink a partition first (for example with Windows Disk Management) to make room."
                    onPicked: win.mode = "alongside"
                }

                Item { width: 1; height: 4 }
                Row {
                    spacing: 10
                    Switch { checked: win.encrypt; onToggled: c => win.encrypt = c; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: I18n.tr("Encrypt Foxtail (FileVault-style)") }
                        Label {
                            text: I18n.tr("Your password will be needed each time the computer starts.")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.px(11)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: language
        Column {
            spacing: 12
            Label { text: I18n.tr("Language & Keyboard"); font.pixelSize: Theme.px(22); font.weight: Font.Bold }
            Row {
                width: parent.width
                spacing: 14
                Column {
                    width: (parent.width - 14) / 2
                    spacing: 6
                    Label { text: I18n.tr("Language"); font.weight: Font.DemiBold }
                    ListBox {
                        width: parent.width
                        height: 290
                        model: win.languages
                        current: win.locale
                        onPicked: v => {
                            win.locale = v;
                            if (win.defaultLayout[v]) win.keymap = win.defaultLayout[v];
                        }
                    }
                }
                Column {
                    width: (parent.width - 14) / 2
                    spacing: 6
                    Label { text: I18n.tr("Keyboard"); font.weight: Font.DemiBold }
                    Rectangle {
                        width: parent.width; height: 26; radius: 7
                        color: Theme.control
                        TextInput {
                            id: kbSearch
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.px(12)
                            onTextChanged: win.layoutFilter = text.toLowerCase()
                            Label { visible: !kbSearch.text; text: I18n.tr("Search layouts"); color: Theme.textTertiary; font.pixelSize: Theme.px(12) }
                        }
                    }
                    ListBox {
                        width: parent.width
                        height: 258
                        model: win.layouts.filter(l => !win.layoutFilter || l[1].toLowerCase().indexOf(win.layoutFilter) >= 0 || l[0] === win.layoutFilter)
                        current: win.keymap
                        onPicked: v => win.keymap = v
                    }
                }
            }
            Label {
                text: I18n.tr("Try typing here to check your keyboard:")
                color: Theme.textSecondary
                font.pixelSize: Theme.px(12)
            }
            Rectangle {
                width: parent.width; height: 28; radius: 7
                color: Theme.control
                border.color: Theme.separator
                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(13)
                }
            }
        }
    }

    Component {
        id: account
        Column {
            spacing: 12
            Label { text: I18n.tr("Create Your Account"); font.pixelSize: Theme.px(22); font.weight: Font.Bold }
            Field { label: I18n.tr("Full name"); text: win.fullName; onEdited: t => win.fullName = t }
            Field { label: I18n.tr("Account name"); text: win.userName; onEdited: t => { win.userEdited = true; win.userName = t; } }
            Field { label: I18n.tr("Password"); secret: true; text: win.password; onEdited: t => win.password = t }
            Field { label: I18n.tr("Verify"); secret: true; text: win.password2; onEdited: t => win.password2 = t }
            Field { label: I18n.tr("Computer name"); text: win.hostName; onEdited: t => win.hostName = t }
            Label {
                visible: win.password2 !== "" && win.password !== win.password2
                text: I18n.tr("Passwords don't match.")
                color: "#FF453A"
                font.pixelSize: Theme.px(12)
            }
        }
    }

    Component {
        id: tz
        Column {
            spacing: 12
            Label { text: I18n.tr("Select Your Time Zone"); font.pixelSize: Theme.px(22); font.weight: Font.Bold }
            Field { label: I18n.tr("Search"); text: win.tzFilter; onEdited: t => win.tzFilter = t }
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
            Label { text: win.error ? "Installation Failed" : "Installing Foxtail…"; font.pixelSize: Theme.px(22); font.weight: Font.Bold }
            Item { width: 1; height: 40 }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 110; height: 110
                sourceSize: Qt.size(220, 220)
                source: Qt.resolvedUrl("../icons/foxtail-logo.png")
                RotationAnimation on rotation {
                    running: win.installing
                    from: 0; to: 360
                    duration: Theme.ms(2400)
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
                    Behavior on width { NumberAnimation { duration: Theme.ms(300) } }
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
            Label { text: I18n.tr("Foxtail is installed 🎉"); font.pixelSize: Theme.px(26); font.weight: Font.Bold }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                text: I18n.tr("Remove the installation media, then restart. You'll log in as “") + win.userName + "”."
            }
        }
    }

    // ---------------- widgets ----------------
    component Choice: Rectangle {
        id: ch
        property bool selected: false
        property string title
        property string sub
        signal picked()
        width: parent?.width ?? 0
        height: chCol.implicitHeight + 20
        radius: 10
        opacity: enabled ? 1 : 0.5
        color: selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : "transparent"
        border.width: selected ? 2 : 1
        border.color: selected ? Theme.accent : Theme.separator
        Rectangle {
            id: radio
            x: 12; y: 12
            width: 16; height: 16; radius: 8
            color: ch.selected ? Theme.accent : "transparent"
            border.width: ch.selected ? 0 : 1.5
            border.color: Theme.textTertiary
            Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: "white"; visible: ch.selected }
        }
        Column {
            id: chCol
            anchors.left: radio.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 10
            spacing: 2
            Label { width: parent.width; text: ch.title; font.weight: Font.DemiBold }
            Label { width: parent.width; text: ch.sub; color: Theme.textSecondary; font.pixelSize: Theme.px(11); wrapMode: Text.Wrap; elide: Text.ElideNone }
        }
        MouseArea { anchors.fill: parent; enabled: ch.enabled; onClicked: ch.picked() }
    }

    // Scrollable single-choice list of [value, label] pairs.
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
                font.pixelSize: Theme.px(13)
                echoMode: f.secret ? TextInput.Password : TextInput.Normal
                text: f.text
                clip: true
                onTextEdited: f.edited(text)
            }
        }
    }
}
