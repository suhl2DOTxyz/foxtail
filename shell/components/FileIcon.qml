import QtQuick
import Quickshell
import qs.services

// A file's picture for the desktop: a thumbnail for images (and for any file
// the file manager has already thumbnailed), otherwise its type icon.
//   file: { name, isDir, suffix }
Item {
    id: root

    property var file
    property string path
    property string uri
    property real size: 60

    width: size
    height: size

    readonly property bool isImage: !file.isDir && ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "tif", "tiff"].indexOf(file.suffix) >= 0
    // Kinds Files makes thumbnails for (documents, videos): use the cached one.
    readonly property bool thumbable: ["pdf", "mp4", "mkv", "mov", "webm", "odt", "ods", "odp", "docx", "xlsx", "pptx", "epub"].indexOf(file.suffix) >= 0
    // Thumbnails other apps made (freedesktop thumbnail cache).
    readonly property string cached: Quickshell.env("HOME") + "/.cache/thumbnails/large/" + Qt.md5(uri) + ".png"

    function iconName() {
        if (file.isDir) return "folder";
        const s = file.suffix;
        const groups = [
            [["pdf"], "application-pdf"],
            [["zip", "tar", "gz", "xz", "bz2", "zst", "7z", "rar", "tgz"], "package-x-generic"],
            [["mp3", "wav", "flac", "ogg", "oga", "m4a", "aac", "opus"], "audio-x-generic"],
            [["mp4", "mkv", "mov", "webm", "avi", "m4v"], "video-x-generic"],
            [["doc", "docx", "odt", "rtf", "pages"], "x-office-document"],
            [["xls", "xlsx", "ods", "csv", "numbers"], "x-office-spreadsheet"],
            [["ppt", "pptx", "odp", "key"], "x-office-presentation"],
            [["html", "htm"], "text-html"],
            [["sh", "py", "js", "ts", "c", "cpp", "h", "rs", "go", "java", "lua", "qml", "json", "xml", "yml", "yaml", "toml"], "text-x-script"],
            [["iso", "img", "dmg"], "media-optical"],
            [["deb", "rpm", "pkg", "flatpak", "appimage"], "package-x-generic"],
            [["ttf", "otf", "woff", "woff2"], "font-x-generic"],
            [["desktop"], "application-x-executable"]
        ];
        for (const g of groups) if (g[0].indexOf(s) >= 0) return g[1];
        return "text-x-generic";
    }

    // Images: the picture itself in a thin white frame, as Finder shows it.
    Rectangle {
        id: frame
        visible: thumb.status === Image.Ready
        anchors.centerIn: parent
        width: thumb.paintedWidth + 6
        height: thumb.paintedHeight + 6
        color: "white"
        radius: 2
        Rectangle {   // soft shadow
            z: -1
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.leftMargin: 1
            anchors.rightMargin: -1
            anchors.bottomMargin: -2
            radius: 3
            color: Qt.rgba(0, 0, 0, 0.18)
        }
    }
    Image {
        id: thumb
        anchors.centerIn: parent
        width: root.size - 8
        height: root.size - 8
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize: Qt.size(160, 160)
        // The modification time in the URL reloads the picture once a file
        // that was still being written (a fresh screenshot) is complete.
        source: root.file.isDir ? "" : root.isImage ? "file://" + root.path + "?" + (root.file.modified?.getTime?.() ?? 0)
              : root.thumbable ? "file://" + root.cached : ""
    }

    Image {
        anchors.fill: parent
        visible: thumb.status !== Image.Ready
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        mipmap: true
        source: Quickshell.iconPath(root.iconName(), "text-x-generic")
    }
}
