import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Keyboard: input sources, key repeat, clipboard history
// and the list of shortcuts.
Column {
    id: pane
    spacing: 14

    property bool adding: false
    property string pick: ""

    SectionTitle { text: I18n.tr("Input Sources") }
    Group {
        Repeater {
            model: Keyboard.layouts
            SettingRow {
                id: srcRow
                required property string modelData
                required property int index
                label: Keyboard.nameFor(modelData)
                sub: index === Keyboard.activeIndex ? "In use" : ""
                last: index === Keyboard.layouts.length - 1
                Row {
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(26, codeLabel.implicitWidth + 10)
                        height: 18
                        radius: 4
                        color: "transparent"
                        border.color: Theme.textSecondary
                        Label { id: codeLabel; anchors.centerIn: parent; text: Keyboard.shortName(srcRow.modelData); font.pixelSize: Theme.px(10); font.weight: Font.Bold; color: Theme.textSecondary }
                    }
                    PushButton {
                        visible: srcRow.index !== Keyboard.activeIndex
                        text: I18n.tr("Use")
                        onClicked: Keyboard.select(srcRow.index)
                    }
                    PushButton {
                        visible: Keyboard.layouts.length > 1
                        text: I18n.tr("Remove")
                        onClicked: Keyboard.remove(srcRow.modelData)
                    }
                }
            }
        }
    }
    Row {
        spacing: 8
        PushButton { visible: !pane.adding; text: I18n.tr("Add Input Source…"); onClicked: { pane.adding = true; filter.text = ""; filter.focusInput(); } }
    }
    Column {
        visible: pane.adding
        width: parent.width
        spacing: 8
        TextField { id: filter; width: parent.width; placeholder: "Search languages and layouts" }
        ListBox {
            width: parent.width
            height: 200
            current: pane.pick
            model: {
                const q = filter.text.trim().toLowerCase();
                return Keyboard.all.filter(l => Keyboard.layouts.indexOf(l[0]) < 0 &&
                    (!q || l[1].toLowerCase().indexOf(q) >= 0 || l[0].indexOf(q) === 0));
            }
            onPicked: v => pane.pick = v
        }
        Row {
            anchors.right: parent.right
            spacing: 8
            PushButton { text: I18n.tr("Cancel"); onClicked: pane.adding = false }
            PushButton {
                text: I18n.tr("Add")
                primary: true
                enabled: pane.pick !== ""
                onClicked: { Keyboard.add(pane.pick); pane.pick = ""; pane.adding = false; }
            }
        }
    }
    Group {
        SettingRow {
            label: I18n.tr("Switch input sources with ⌃Space")
            sub: I18n.tr("You can also pick one from the menu bar.")
            last: true
            Switch { checked: Settings.layoutSwitchShortcut; onToggled: c => Settings.layoutSwitchShortcut = c }
        }
    }

    SectionTitle { text: I18n.tr("Typing") }
    Group {
        SettingRow {
            label: I18n.tr("Key repeat rate")
            Row {
                spacing: 10
                Label { text: I18n.tr("Slow"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider {
                    width: 150
                    anchors.verticalCenter: parent.verticalCenter
                    from: 10; to: 60
                    value: Settings.keyRepeatRate
                    onReleased: Settings.keyRepeatRate = Math.round(value)
                }
                Label { text: I18n.tr("Fast"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SettingRow {
            label: I18n.tr("Delay until repeat")
            last: true
            Row {
                spacing: 10
                Label { text: I18n.tr("Long"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider {
                    width: 150
                    anchors.verticalCenter: parent.verticalCenter
                    from: 900; to: 200
                    value: Settings.keyRepeatDelay
                    onReleased: Settings.keyRepeatDelay = Math.round(value / 50) * 50
                }
                Label { text: I18n.tr("Short"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Group {
        SettingRow {
            label: I18n.tr("Clipboard history")
            sub: I18n.tr("Remember what you copy. Open the history with ⌥⌘V.")
            last: true
            Row {
                spacing: 8
                PushButton { text: I18n.tr("Clear"); anchors.verticalCenter: parent.verticalCenter; onClicked: Clipboard.clear() }
                Switch { anchors.verticalCenter: parent.verticalCenter; checked: Settings.clipboardHistory; onToggled: c => Settings.clipboardHistory = c }
            }
        }
    }

    SectionTitle { text: I18n.tr("Keyboard Shortcuts") }
    Note { text: I18n.tr("The Super (⊞) key is ⌘ Command, Ctrl is ⌃ Control, Alt is ⌥ Option. ⌘ shortcuts work in every app, and in terminals ⌘C copies instead of interrupting.") }
    Group {
        Repeater {
            id: shortcuts
            model: [
                ["Copy, Paste, Cut, Undo, Select All", "⌘C  ⌘V  ⌘X  ⌘Z  ⌘A"],
                ["Quit app (all its windows)", "⌘Q"],
                ["Close tab or window", "⌘W"],
                ["Hide / Minimize", "⌘H  /  ⌘M"],
                ["Spotlight", "⌘ Space"],
                ["Switch apps / windows of an app", "⌘ Tab  /  ⌘`"],
                ["Mission Control", "F3  /  ⌃↑"],
                ["Clipboard history", "⌥⌘V"],
                ["Next input source", "⌃ Space"],
                ["Line start / end, word jump", "⌘← ⌘→  /  ⌥← ⌥→"],
                ["Back / Forward", "⌘[  /  ⌘]"],
                ["Full screen", "⌃⌘F"],
                ["Switch desktop", "⌃1 … 9  /  ⌃⌘← →"],
                ["Move window to desktop", "⌃⇧1 … 9"],
                ["Apps", "F4  /  ⌥⌘L"],
                ["Control Center", "⌥⌘C"],
                ["Files  /  Terminal", "⌥⌘Space  /  ⌥⌘Return"],
                ["Lock screen", "⌃⌘Q"],
                ["Force Quit", "⌥⌘⎋"],
                ["Screenshot: screen / area", "⇧⌘3  /  ⇧⌘4"],
                ["Screenshot and recording toolbar", "⇧⌘5"]
            ]
            SettingRow {
                required property var modelData
                required property int index
                label: I18n.tr(modelData[0])
                last: index === shortcuts.count - 1
                Label { text: modelData[1]; color: Theme.textSecondary; font.family: Theme.font }
            }
        }
    }

    // ---- Custom shortcuts: open an app or run a command (written to
    // generated.lua by HyprConfig) ----
    SectionTitle { text: I18n.tr("Custom Shortcuts") }
    Note { text: I18n.tr("Open an app or run a command with your own key combination. Use at least one modifier; combinations Foxtail already uses (above) would do both things.") }
    Group {
        id: custom
        readonly property var modSyms: [["CTRL", "⌃"], ["ALT", "⌥"], ["SHIFT", "⇧"], ["SUPER", "⌘"]]
        function combo(sc) {
            return modSyms.filter(m => sc.mods.indexOf(m[0]) >= 0).map(m => m[1]).join("") + sc.key;
        }
        function describe(sc) {
            if (sc.app) return I18n.tr("Open %1").replace("%1", Apps.title(Apps.entry(sc.app)) || sc.app);
            return sc.command;
        }

        Repeater {
            model: Settings.customShortcuts
            SettingRow {
                required property var modelData
                required property int index
                label: custom.describe(modelData)
                Row {
                    spacing: 10
                    Label { text: custom.combo(modelData); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    PushButton {
                        text: I18n.tr("Remove")
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Settings.customShortcuts = Settings.customShortcuts.filter((_, i) => i !== index)
                    }
                }
            }
        }

        // The editor: modifiers, key, and what it does.
        Item {
            id: editor
            width: parent.width
            height: editCol.implicitHeight + 20
            property var mods: ["SUPER", "ALT"]
            property string target: Apps.all.length ? Apps.all[0].id : ""
            readonly property bool isCommand: target === "__command__"
            readonly property string key: {
                const k = keyField.text.trim();
                if (/^[A-Za-z0-9]$/.test(k)) return k.toUpperCase();
                if (/^[Ff]([1-9]|1[0-2])$/.test(k)) return k.toUpperCase();
                return "";
            }
            readonly property bool valid: mods.length > 0 && key !== ""
                                          && (isCommand ? cmdField.text.trim() !== "" : target !== "")

            Column {
                id: editCol
                x: 14
                y: 10
                width: parent.width - 28
                spacing: 10
                Row {
                    spacing: 6
                    Repeater {
                        model: custom.modSyms
                        Rectangle {
                            required property var modelData
                            readonly property bool on: editor.mods.indexOf(modelData[0]) >= 0
                            width: 30; height: 26; radius: 7
                            color: on ? Theme.accent : Theme.control
                            border.color: on ? "transparent" : Theme.separator
                            Label { anchors.centerIn: parent; text: modelData[1]; color: parent.on ? "white" : Theme.text; font.pixelSize: Theme.px(13) }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: editor.mods = parent.on ? editor.mods.filter(m => m !== modelData[0])
                                                                 : editor.mods.concat([modelData[0]])
                            }
                        }
                    }
                    TextField {
                        id: keyField
                        width: 56
                        placeholder: I18n.tr("Key")
                    }
                    Choice {
                        id: what
                        width: 210
                        menuWidth: 240
                        options: Apps.all.map(e => [e.id, I18n.tr("Open %1").replace("%1", Apps.title(e))])
                                 .concat([["__command__", I18n.tr("Run a Command…")]])
                        value: editor.target
                        onPicked: v => editor.target = v
                    }
                }
                TextField {
                    id: cmdField
                    visible: editor.isCommand
                    width: parent.width
                    placeholder: I18n.tr("Command, e.g. firefox --private-window")
                }
                PushButton {
                    text: I18n.tr("Add Shortcut")
                    primary: true
                    enabled: editor.valid
                    onClicked: {
                        Settings.customShortcuts = Settings.customShortcuts.concat([{
                            mods: editor.mods.slice(), key: editor.key,
                            app: editor.isCommand ? "" : editor.target,
                            command: editor.isCommand ? cmdField.text.trim() : ""
                        }]);
                        keyField.text = "";
                        cmdField.text = "";
                    }
                }
            }
        }
    }
}
