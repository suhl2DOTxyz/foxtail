pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. `banners` are the transient pop-ups in the top right;
// `history` is what Notification Center lists.
Singleton {
    id: root

    property list<var> banners: []
    readonly property var history: server.trackedNotifications.values

    function dismissBanner(n) {
        banners = banners.filter(b => b !== n);
    }

    // Unread notifications from an app, for its red badge in the Dock.
    function countFor(appId) {
        if (!appId) return 0;
        const id = appId.toLowerCase();
        const name = Apps.nameFor(appId);
        return history.filter(n => (n.desktopEntry && n.desktopEntry.toLowerCase() === id) || (!n.desktopEntry && n.appName === name)).length;
    }

    function clearAll() {
        for (const n of history.slice()) n.dismiss();
        banners = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            if (!Settings.doNotDisturb || n.urgency === NotificationUrgency.Critical) {
                root.banners = [n].concat(root.banners).slice(0, 4);
                if (!(n.hints?.["suppress-sound"] ?? false)) Sounds.play("notification");
            }
        }
    }
}
