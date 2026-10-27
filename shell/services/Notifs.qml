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

    // When each notification arrived (by id), for "5m ago".
    property var arrived: ({})
    // Ticks once a minute so relative times stay current.
    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = new Date() }
    function ago(n) {
        if (!n) return "";
        void now;
        const t = arrived[n.id];
        if (!t) return "";
        const m = Math.floor((now.getTime() - t) / 60000);
        if (m < 1) return I18n.tr("now");
        if (m < 60) return I18n.tr("%1m ago").arg(m);
        const h = Math.floor(m / 60);
        if (h < 24) return I18n.tr("%1h ago").arg(h);
        return I18n.date(new Date(t), "MMM d");
    }

    // A reply is being typed in a banner (it needs the keyboard meanwhile).
    property bool replying: false

    // Notification Center groups notifications by app, newest first:
    // [{ key, app, items: [notification, ...] }]
    readonly property var groups: {
        const map = {};
        const order = [];
        for (const n of history.slice().reverse()) {
            const key = (n.desktopEntry || n.appName || "?").toLowerCase();
            if (!map[key]) { map[key] = { key, app: n.appName || n.desktopEntry, items: [] }; order.push(key); }
            map[key].items.push(n);
        }
        return order.map(k => map[k]);
    }
    function dismissGroup(key) {
        const g = groups.find(g => g.key === key);
        for (const n of (g?.items ?? []).slice()) n.dismiss();
    }

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
        inlineReplySupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const a = Object.assign({}, root.arrived);
            a[n.id] = Date.now();
            root.arrived = a;
            if (!Settings.doNotDisturb || n.urgency === NotificationUrgency.Critical) {
                root.banners = [n].concat(root.banners).slice(0, 4);
                if (!(n.hints?.["suppress-sound"] ?? false)) Sounds.play("notification");
            }
        }
    }
}
