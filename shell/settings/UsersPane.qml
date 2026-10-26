import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// System Settings › Users & Groups: the accounts on this computer. Changes
// run /usr/bin/foxtail-users through pkexec (administrator password).
Column {
    id: pane
    spacing: 14

    property var users: []          // [{ name, full, admin }]
    property string mode: ""        // "" | "add" | "password:<user>"
    property string confirmDelete: ""
    property string error: ""
    property bool busy: false

    function refresh() { lister.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: lister
        command: ["sh", "-c", "w=$(getent group wheel | cut -d: -f4); getent passwd | awk -F: -v w=\",$w,\" '$3>=1000 && $3<60000 {split($5,g,\",\"); print $1 \"\\t\" g[1] \"\\t\" (index(w, \",\" $1 \",\") ? 1 : 0)}'"]
        stdout: StdioCollector {
            onStreamFinished: pane.users = text.trim().split("\n").filter(l => l).map(l => {
                const f = l.split("\t");
                return { name: f[0], full: f[1] || f[0], admin: f[2] === "1" };
            })
        }
    }

    Process {
        id: helper
        // The password goes in over stdin once the helper has started, never in argv.
        property string pending: ""
        stderr: StdioCollector { id: helperErr }
        // (The helper reads a single line, so stdin can stay open.)
        onStarted: {
            if (pending === "") return;
            write(pending + "\n");
            pending = "";
        }
        onExited: code => {
            pane.busy = false;
            if (code === 0) {
                pane.error = "";
                pane.mode = "";
                pane.confirmDelete = "";
            } else {
                pane.error = code === 126 || code === 127 ? "Authentication was cancelled." : (helperErr.text.trim() || "That didn't work.");
            }
            pane.refresh();
        }
    }
    function run(args, stdin) {
        busy = true;
        helper.command = ["pkexec", "/usr/bin/foxtail-users"].concat(args);
        helper.pending = stdin ?? "";
        helper.stdinEnabled = stdin !== undefined;
        helper.running = true;
    }

    Group {
        Repeater {
            model: pane.users
            SettingRow {
                id: urow
                required property var modelData
                required property int index
                readonly property bool me: modelData.name === SystemInfo.user
                icon: "person"
                label: modelData.full + (me ? " (you)" : "")
                sub: (modelData.admin ? "Administrator" : "Standard") + " · " + modelData.name
                last: index === pane.users.length - 1
                Row {
                    spacing: 6
                    PushButton {
                        text: "Password…"
                        onClicked: { pane.mode = "password:" + urow.modelData.name; pw1.text = ""; pw2.text = ""; pw1.focusInput(); }
                    }
                    PushButton {
                        visible: !urow.me
                        text: urow.modelData.admin ? "Make Standard" : "Make Admin"
                        onClicked: pane.run(["admin", urow.modelData.name, urow.modelData.admin ? "0" : "1"])
                    }
                    PushButton {
                        visible: !urow.me
                        text: pane.confirmDelete === urow.modelData.name ? "Delete account and files" : "Delete…"
                        destructive: true
                        onClicked: {
                            if (pane.confirmDelete === urow.modelData.name) pane.run(["delete", urow.modelData.name, "0"]);
                            else pane.confirmDelete = urow.modelData.name;
                        }
                    }
                }
            }
        }
    }
    PushButton {
        visible: pane.mode === ""
        text: "Add User…"
        onClicked: { pane.mode = "add"; nfull.text = ""; nuser.text = ""; pw1.text = ""; pw2.text = ""; nfull.focusInput(); }
    }

    // ---------- add user / change password ----------
    Group {
        visible: pane.mode !== ""
        Item {
            width: parent.width
            height: 40
            Label {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                font.weight: Font.DemiBold
                text: pane.mode === "add" ? "New account" : "Change password for " + pane.mode.slice(9)
            }
        }
        SettingRow {
            visible: pane.mode === "add"
            label: "Full name"
            TextField {
                id: nfull
                width: 240
                onTextChanged: if (!nuser.edited) nuser.text = text.toLowerCase().normalize("NFD").replace(/[^a-z0-9]/g, "").slice(0, 32)
            }
        }
        SettingRow {
            visible: pane.mode === "add"
            label: "Account name"
            sub: "Used for the home folder. It can't be changed later."
            TextField {
                id: nuser
                property bool edited: false
                width: 240
                onTextChanged: if (activeFocus) edited = true
            }
        }
        SettingRow {
            label: "Password"
            TextField { id: pw1; width: 240; secret: true }
        }
        SettingRow {
            label: "Verify"
            TextField { id: pw2; width: 240; secret: true }
        }
        SettingRow {
            visible: pane.mode === "add"
            label: "Allow this user to administer this computer"
            Switch { id: nadmin; checked: false }
        }
        Item {
            width: parent.width
            height: 46
            Label {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: pw2.text !== "" && pw1.text !== pw2.text
                text: "Passwords don't match"
                color: "#FF453A"
                font.pixelSize: 12
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                PushButton { text: "Cancel"; onClicked: { pane.mode = ""; pane.error = ""; } }
                PushButton {
                    text: pane.mode === "add" ? "Create User" : "Change Password"
                    primary: true
                    enabled: !pane.busy && pw1.text !== "" && pw1.text === pw2.text
                             && (pane.mode !== "add" || (nuser.text !== "" && nfull.text !== ""))
                    onClicked: {
                        if (pane.mode === "add") pane.run(["add", nuser.text, nfull.text, nadmin.checked ? "1" : "0"], pw1.text);
                        else pane.run(["passwd", pane.mode.slice(9)], pw1.text);
                    }
                }
            }
        }
    }
    Label {
        visible: pane.error !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: pane.error
        color: "#FF453A"
        font.pixelSize: 12
    }
}
