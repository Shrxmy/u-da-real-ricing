// Notification daemon for Hyprland (Plasma keeps its own): retro-window popups top-right, and a dropdown
// center under the bar bell. Idle = no windows, timers or animations; nothing redraws until a notification.
//   systemctl --user start qs-notifications                 start (look.lua autostart; D-Bus activation too)
//   qs -c notifications ipc call notifications toggle       open/close the center (bar bell, Super+N)
//   qs -c notifications ipc call notifications dnd          toggle Do Not Disturb
//   qs -c notifications ipc call notifications clear        dismiss everything
// Popups that time out stay in the center (missed); click, ×, or the app closing it removes it everywhere.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import "lib.js" as L

ShellRoot {
    id: root

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
    readonly property int maxPopups: 4
    readonly property int maxHistory: 50

    property color accent: "#cc9166" // replaced by the wallpaper accent below
    property color sand: "#d9ac8c"
    readonly property bool animate: !UPower.onBattery // same as look.lua: no animations on battery
    property bool dnd: false
    property bool centerOpen: false
    property int unread: 0 // arrived since the center was last opened (and still around)
    property var unreadIds: ({})
    property real now: Date.now()
    property var arrived: ({}) // notification id -> ms, for the "2m" labels
    property var live: ({}) // notification id -> object, for popup delegates
    readonly property var history: server.trackedNotifications.values.slice().reverse() // newest first

    property int tokens: 0

    function suppressed(n) { return dnd && n.urgency !== NotificationUrgency.Critical }

    // new notification, or the app replaced one (same object): show it on top with a fresh timer
    function arrive(n) {
        arrived[n.id] = Date.now()
        if (centerOpen) return // it's already on screen in the center
        if (suppressed(n)) {
            dropPopup(n.id)
            if (n.transient) n.expire()
            return
        }
        live[n.id] = n
        const i = popupIndex(n.id)
        if (i >= 0) { // already up: update in place, no second slide-in
            popupModel.move(i, 0, 1)
            popupModel.setProperty(0, "token", ++tokens)
        } else {
            popupModel.insert(0, { nid: n.id, token: ++tokens })
        }
        while (popupModel.count > maxPopups) retire(popupModel.get(popupModel.count - 1).nid) // oldest -> center
    }

    function setUnread(id, on) {
        if (on) unreadIds[id] = true
        else delete unreadIds[id]
        unread = Object.keys(unreadIds).length
    }

    function popupIndex(id) {
        for (let i = 0; i < popupModel.count; i++) if (popupModel.get(i).nid === id) return i
        return -1
    }

    function dropPopup(id) {
        const i = popupIndex(id)
        if (i >= 0) popupModel.remove(i)
    }

    // popup leaves the screen but the notification stays in the center, unless the app said not to keep it.
    // token: only the timer of the popup currently showing may retire it (not one still fading out)
    function retire(id, token) {
        const i = popupIndex(id)
        if (i < 0 || (token !== undefined && popupModel.get(i).token !== token)) return
        const n = live[id]
        popupModel.remove(i)
        if (n && n.transient) n.expire()
    }

    function finish(n) { // handled by the user: gone from popups and center, app is told
        if (n && n.tracked) n.dismiss()
    }

    // click = go to the app: its default action if it has one, and focus its window either way
    // (apps can't raise themselves under Hyprland's focus rules, so the action alone often does nothing visible)
    function activate(n) {
        if (!n) return
        const def = Array.from(n.actions).find(a => a.identifier === "default")
        focusApp([n.desktopEntry, n.appName])
        if (def) def.invoke()
        finish(n)
    }

    function runAction(n, action) {
        if (!n) return
        const resident = n.resident
        action.invoke()
        if (!resident) finish(n)
    }

    function setCenter(open) {
        centerOpen = open
        if (!open) return
        unreadIds = {}
        unread = 0
        while (popupModel.count > 0) retire(popupModel.get(0).nid) // they're all in the center now
    }

    function clearAll() {
        for (const n of history) n.dismiss()
    }

    function focusApp(keys) {
        clients.keys = keys
        clients.running = true
    }

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            if (!root.centerOpen) root.setUnread(n.id, true)
            const id = n.id
            n.closed.connect(() => { root.dropPopup(id); root.setUnread(id, false); delete root.live[id]; delete root.arrived[id] })
            // replace-id updates arrive on the same object (no new signal): show it again.
            // Several of these fire for one replace; arrive() is idempotent, so that's fine.
            n.summaryChanged.connect(() => root.arrive(n))
            n.bodyChanged.connect(() => root.arrive(n))
            n.hintsChanged.connect(() => root.arrive(n))
            root.arrive(n)
            const all = trackedNotifications.values
            if (all.length > root.maxHistory) all[0].expire()
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.setCenter(!root.centerOpen) }
        function dnd(): void { root.dnd = !root.dnd }
        function clear(): void { root.clearAll() }
    }

    // wallpaper.sh writes "ACCENT SAND"; recolor live when it changes
    FileView {
        path: root.stateDir + "/wallpaper/accent"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^([0-9a-fA-F]{6})\s+([0-9a-fA-F]{6})/)
            if (m) { root.accent = "#" + m[1]; root.sand = "#" + m[2] }
        }
    }

    // bar bell: waybar's custom/notifications cats this file, and re-reads it on SIGRTMIN+9
    FileView {
        id: barFile
        path: root.stateDir + "/notifications.json"
        blockLoading: true
        printErrors: false
        onSaved: barSignal.startDetached()
    }
    Process { id: barSignal; command: ["pkill", "-RTMIN+9", "-x", "waybar"] }
    function pushBar() { barFile.setText(JSON.stringify(L.barState(unread, history.length, dnd)) + "\n") }
    onUnreadChanged: Qt.callLater(pushBar)
    onHistoryChanged: Qt.callLater(pushBar)
    onDndChanged: {
        for (let i = popupModel.count - 1; i >= 0; i--) { // turning DND on clears what it would have hidden
            const n = live[popupModel.get(i).nid]
            if (n && suppressed(n)) retire(n.id)
        }
        Qt.callLater(pushBar)
    }
    Component.onCompleted: pushBar()

    Process {
        id: clients
        property var keys: []
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try { list = JSON.parse(text) } catch (e) {}
                const address = L.pickWindow(list, clients.keys)
                if (!address) return
                focus.command = ["hyprctl", "dispatch", `hl.dsp.focus({ window = "address:${address}" })`]
                focus.startDetached()
            }
        }
    }
    Process { id: focus }

    // relative times only tick while something on screen shows one
    Timer {
        interval: 30000
        repeat: true
        triggeredOnStart: true
        running: root.centerOpen || popupModel.count > 0
        onTriggered: root.now = Date.now()
    }

    ListModel { id: popupModel } // { nid }, newest first

    // ---- popups ----
    PanelWindow {
        visible: popupModel.count > 0 || linger.running
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notifications"
        anchors { top: true; right: true } // default exclusion: sits under waybar
        margins { top: 6; right: 8 }
        implicitWidth: 344
        implicitHeight: Math.max(1, popups.contentHeight)
        color: "transparent"

        Timer { id: linger; interval: 260 } // keep the window while the last one fades out
        Connections {
            target: popupModel
            function onCountChanged() { if (popupModel.count === 0) linger.restart() }
        }

        ListView {
            id: popups
            anchors.fill: parent
            model: popupModel
            spacing: 8
            interactive: false

            add: Transition {
                enabled: root.animate
                NumberAnimation { property: "x"; from: 344; to: 0; duration: 240; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                enabled: root.animate
                NumberAnimation { property: "opacity"; to: 0; duration: 180 }
            }
            displaced: Transition {
                enabled: root.animate
                NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
            }

            delegate: Card {
                required property int nid
                width: popups.width
                n: root.live[nid] ?? null
                accent: root.accent
                sand: root.sand
                arrived: root.arrived[nid] ?? Date.now()
                now: root.now
                onActivated: root.activate(n)
                onCloseClicked: root.finish(n)
                onTimedOut: root.retire(nid, token)
                onActionClicked: action => root.runAction(n, action)
            }
        }
    }

    // ---- center: dropdown under the bell ----
    PanelWindow {
        visible: root.centerOpen
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notifications-center"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true } // under the bar, so the bell still toggles
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: root.setCenter(false) } // click outside closes

        Item {
            id: panel
            anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 12 }
            width: 324
            height: frame.height + 5
            focus: true
            Keys.onEscapePressed: root.setCenter(false)

            Rectangle { x: 5; y: 5; width: frame.width; height: frame.height; color: "#141216" } // pixel shadow

            Rectangle {
                id: frame
                width: panel.width - 5
                height: body.implicitHeight + 4
                color: "#25222a"
                border.color: root.accent
                border.width: 2

                MouseArea { anchors.fill: parent } // clicks inside don't close

                Column {
                    id: body
                    x: 2; y: 2
                    width: parent.width - 4

                    Rectangle { // title bar
                        width: parent.width
                        height: 20
                        color: root.accent
                        Text {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            text: "notifications · " + root.history.length
                            color: "#25222a"
                            font { family: "Inconsolata Nerd Font"; pixelSize: 11; bold: true; capitalization: Font.AllUppercase; letterSpacing: 0.7 }
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: "×"
                            color: "#25222a"
                            font { family: "Inconsolata Nerd Font"; pixelSize: 14; bold: true }
                            MouseArea { anchors { fill: parent; margins: -4 } onClicked: root.setCenter(false) }
                        }
                    }

                    Item { // toolbar
                        width: parent.width
                        height: 36
                        RetroButton {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "󰂛 dnd"
                            on: root.dnd
                            sand: root.sand
                            onClicked: root.dnd = !root.dnd
                        }
                        RetroButton {
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "clear all"
                            on: root.history.length > 0
                            sand: root.sand
                            onClicked: root.clearAll()
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#302c36" }
                    }

                    Text {
                        visible: root.history.length === 0
                        width: parent.width
                        padding: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: "all caught up"
                        color: "#8a8a8a"
                        font { family: "Inconsolata Nerd Font"; pixelSize: 13 }
                    }

                    ListView {
                        id: rows
                        visible: root.history.length > 0
                        width: parent.width
                        height: Math.min(contentHeight, 420) + 12
                        topMargin: 6; bottomMargin: 6
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.history

                        delegate: Item {
                            id: row
                            required property var modelData
                            readonly property var n: modelData
                            readonly property bool critical: n.urgency === NotificationUrgency.Critical
                            readonly property string img: L.imageSource(n.image, n.appIcon)
                            width: rows.width
                            height: inner.implicitHeight + 12

                            Rectangle {
                                x: 10; width: parent.width - 20; height: parent.height
                                color: rowMouse.containsMouse ? "#38333f" : "#302c36"
                                Rectangle { width: 3; height: parent.height; color: row.critical ? "#a97070" : "#4d4d4d" }

                                Row {
                                    id: inner
                                    x: 11; y: 6
                                    width: parent.width - 19
                                    spacing: 8

                                    Image {
                                        visible: row.img !== ""
                                        source: row.img
                                        width: 34; height: 34
                                        sourceSize: Qt.size(68, 68)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                    Column {
                                        width: inner.width - (row.img !== "" ? 42 : 0) - time.width - 8
                                        Text {
                                            width: parent.width
                                            text: "<b>" + L.esc(row.n.summary) + "</b>"
                                                + (row.n.appName ? " <font color='#8a8a8a'>· " + L.esc(row.n.appName) + "</font>" : "")
                                            textFormat: Text.StyledText
                                            color: row.critical ? "#a97070" : root.sand
                                            font { family: "Inconsolata Nerd Font"; pixelSize: 13 }
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            visible: text !== ""
                                            text: L.cleanBody(row.n.body)
                                            textFormat: Text.StyledText
                                            color: "#c6c0b9"
                                            font { family: "Inconsolata Nerd Font"; pixelSize: 12 }
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Text {
                                        id: time
                                        text: L.relTime(root.arrived[row.n.id] ?? root.now, root.now)
                                        color: "#8a8a8a"
                                        font { family: "Inconsolata Nerd Font"; pixelSize: 11 }
                                    }
                                }
                            }

                            MouseArea { // left = go to the app, right = just remove it
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) { root.finish(row.n); return }
                                    root.activate(row.n)
                                    root.setCenter(false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
