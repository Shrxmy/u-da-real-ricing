// Pure helpers for shell.qml (no QML types here, so `node selftest.js` can check them).

// Window to focus for a notification: hyprctl clients -j entries vs the app's desktop entry / name.
// Classes vary ("Spotify", "org.telegram.desktop._845d…", "brave-origin"), so match case-insensitively by prefix.
function pickWindow(clients, keys) {
    const ks = keys.map(k => (k || "").toLowerCase()).filter(k => k.length >= 3)
    if (!ks.length) return ""
    const hit = c => {
        const cls = (c.class || "").toLowerCase()
        return cls.length >= 3 && ks.some(k => cls === k || cls.startsWith(k) || k.startsWith(cls))
    }
    // most recently focused first; hyprctl's focusHistoryID is 0 for the current window
    const win = clients.filter(hit).sort((a, b) => (a.focusHistoryID ?? 1e9) - (b.focusHistoryID ?? 1e9))[0]
    return win && /^0x[0-9a-f]+$/.test(win.address) ? win.address : "" // address goes into a Lua dispatch
}

function relTime(ms, now) {
    const s = Math.max(0, Math.floor((now - ms) / 1000))
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    return Math.floor(s / 86400) + "d"
}

// Popup lifetime in ms: app timeout if it set one (D-Bus ms, as Quickshell passes it), 0 = stays until closed.
function timeoutMs(expireTimeout, critical) {
    if (critical || expireTimeout === 0) return 0
    return expireTimeout > 0 ? expireTimeout : 5000
}

// Body markup for Text.StyledText, without <img> (could load remote/local files the app points at).
function cleanBody(body) {
    return (body || "").replace(/<img\b[^>]*>/gi, "")
}

// Picture for the card: the notification image, else an app icon only when it's a file (Spotify art, chat avatars).
function imageSource(image, appIcon) {
    for (const s of [image || "", appIcon || ""]) {
        if (s.startsWith("/")) return "file://" + s
        if (s.startsWith("file://") || (s === image && s.startsWith("image://"))) return s
    }
    return ""
}

function esc(s) {
    return (s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Waybar custom module payload.
function barState(unread, total, dnd) {
    if (dnd) return { text: "󰂛", class: "dnd", tooltip: "Do not disturb · " + total + " in center" }
    if (unread > 0) return { text: "󰂚 " + unread, class: "unread", tooltip: unread + " unread" }
    return { text: "󰂚", class: "none", tooltip: total ? total + " in center" : "No notifications" }
}
