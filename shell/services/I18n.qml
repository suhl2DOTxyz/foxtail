pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Translations for the shell. Strings are written in English in the code and
// looked up with I18n.tr("…") in shell/i18n/<language>.json (the language
// chosen in the installer: LANG). Missing entries stay English.
//   I18n.tr("Hide %1").arg(name)
Singleton {
    id: root

    readonly property string language: {
        const l = Quickshell.env("LC_MESSAGES") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "en";
        return l.split(/[_.@]/)[0].toLowerCase();       // "de_DE.UTF-8" -> "de", "C.UTF-8" -> "c"
    }
    readonly property bool english: language === "en" || language === "c"
    property var table: ({})

    FileView {
        path: root.english ? "" : Qt.resolvedUrl("../i18n/" + root.language + ".json").toString().replace("file://", "")
        printErrors: false
        onLoaded: {
            try { root.table = JSON.parse(text()); } catch (e) { root.table = {}; }
        }
    }

    // Dates in the user's language ("Di. 27. Okt."), e.g. I18n.date(d, "ddd d MMM").
    readonly property var locale: Qt.locale(english ? "en_US" : (Quickshell.env("LANG")?.split(".")[0] || "en_US"))
    function date(d, fmt) {
        return locale.toString(d, fmt);
    }

    function tr(s) {
        return table[s] ?? s;
    }
}
