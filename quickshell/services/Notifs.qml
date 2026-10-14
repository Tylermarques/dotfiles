pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Notification daemon (org.freedesktop.Notifications).
//   popups   live notifications currently shown as popups (ids, newest first)
//   history  plain snapshots, newest first, capped at notifications.historyCap and
//            saved to disk with a debounce (Ignis rewrote an unbounded file on
//            every notification, which is what froze it)
Singleton {
    id: root

    readonly property bool dnd: Config.notifications.dnd
    property var history: []
    property var live: ({})          // id -> Notification, while the sender keeps it
    readonly property alias popups: popupModel
    // After a hot reload the kept server re-sends what it still tracks; those
    // must not pop up again. Anything arriving after this settles is new.
    property bool settled: false

    function setDnd(value: bool): void { Config.notifications.dnd = value; }

    // History keys are unique across restarts (server ids restart at 1, but
    // instanceId changes with each run and survives hot reloads).
    function keyOf(id: int): string { return `${Quickshell.instanceId}:${id}`; }

    // Live object behind a popup id or history entry, if the sender still has it.
    function get(id: int): Notification { return live[id] ?? null; }
    function liveFor(entry: var): Notification {
        return entry.key === keyOf(entry.nid) ? get(entry.nid) : null;
    }

    // User closed it: tell the app (its `closed` then removes it everywhere).
    function dismiss(id: int): void {
        const n = get(id);
        n ? n.dismiss() : forget(keyOf(id), id);
    }
    function dismissEntry(entry: var): void {
        const n = liveFor(entry);
        n ? n.dismiss() : forget(entry.key, -1);
    }

    function clearAll(): void {
        for (const id of Object.keys(live))
            live[id].dismiss();
        history = [];
        popupModel.clear();
        save.restart();
    }

    function hidePopup(id: int): void {
        for (let i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).nid === id) {
                popupModel.remove(i);
                return;
            }
        }
    }

    function forget(key: string, id: int): void {
        if (id >= 0)
            hidePopup(id);
        const before = history.length;
        history = history.filter(e => e.key !== key);
        if (history.length !== before)
            save.restart();
    }

    function snapshot(n: Notification): var {
        const iconPrefix = "image://icon/";
        const pathLike = s => s.startsWith("/") || s.startsWith("file://");
        return {
            key: keyOf(n.id),
            nid: n.id,
            time: Date.now(),
            appName: n.appName,
            // Icon names and file paths survive a restart; inline image data doesn't.
            appIcon: n.image.startsWith(iconPrefix) ? n.image.slice(iconPrefix.length)
                : n.appIcon.startsWith("image://") ? "" : n.appIcon,
            image: pathLike(n.image) ? n.image : "",
            summary: n.summary,
            body: n.body,
            urgency: n.urgency
        };
    }

    function onNotified(n: Notification): void {
        n.tracked = true;
        live[n.id] = n;
        n.closed.connect(() => {
            delete root.live[n.id];
            root.forget(root.keyOf(n.id), n.id);
        });

        const key = keyOf(n.id);
        const resent = !settled && history.some(e => e.key === key);
        if (resent)
            return;

        if (!n.transient && !Config.notifications.noHistoryApps.includes(n.appName)) {
            const next = [snapshot(n), ...history.filter(e => e.key !== key)];
            // Over the cap: tell senders their oldest notifications are gone.
            for (const old of next.splice(Config.notifications.historyCap))
                liveFor(old)?.expire();
            history = next;
            save.restart();
        }

        if (!dnd) {
            hidePopup(n.id);
            popupModel.insert(0, { nid: n.id });
            while (popupModel.count > Config.notifications.maxPopups)
                popupModel.remove(popupModel.count - 1);
        }
    }

    Timer {
        running: true
        interval: 2000
        onTriggered: root.settled = true
    }

    ListModel { id: popupModel }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true
        onNotification: n => root.onNotified(n)
    }

    FileView {
        id: store
        path: Quickshell.statePath("notifications.json")
        blockLoading: true   // small file; history must exist before resent notifications arrive
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text()).filter(e => typeof e.key === "string");
                const keys = new Set(root.history.map(e => e.key));
                root.history = [...root.history, ...saved.filter(e => !keys.has(e.key))]
                    .slice(0, Config.notifications.historyCap);
            } catch (e) {
                console.warn("Notifs: ignoring unreadable history", e);
            }
        }
    }

    Timer {
        id: save
        interval: 1000
        onTriggered: store.setText(JSON.stringify(root.history))
    }

    IpcHandler {
        target: "notifs"

        function toggleDnd(): void { root.setDnd(!root.dnd); }
        function setDnd(value: bool): void { root.setDnd(value); }
        function clear(): void { root.clearAll(); }
        function count(): int { return root.history.length; }
    }
}
