// node quickshell/notifications/selftest.js
const assert = require("assert")
const src = require("fs").readFileSync(__dirname + "/lib.js", "utf8")
const L = new Function(src + "; return { pickWindow, relTime, timeoutMs, cleanBody, barState, imageSource, esc }")()

assert.equal(L.imageSource("image://qsimage/1", "spotify"), "image://qsimage/1")
assert.equal(L.imageSource("", "/tmp/art.jpg"), "file:///tmp/art.jpg")
assert.equal(L.imageSource("", "dialog-information"), "", "themed icon names are skipped")
assert.equal(L.imageSource("", "image://evil"), "", "only the image hint may be image://")
assert.equal(L.esc("<b>&"), "&lt;b&gt;&amp;")

const clients = [
    { class: "org.telegram.desktop._845d5d91", address: "0xaa", focusHistoryID: 3 },
    { class: "Spotify", address: "0xbb", focusHistoryID: 2 },
    { class: "brave-origin", address: "0xcc", focusHistoryID: 1 },
    { class: "Alacritty", address: "0xdd", focusHistoryID: 0 },
    { class: "Alacritty", address: "0xee", focusHistoryID: 4 },
]
assert.equal(L.pickWindow(clients, ["spotify", "Spotify"]), "0xbb")
assert.equal(L.pickWindow(clients, ["org.telegram.desktop", "Telegram Desktop"]), "0xaa")
assert.equal(L.pickWindow(clients, ["", "Brave"]), "0xcc")
assert.equal(L.pickWindow(clients, ["alacritty"]), "0xdd", "most recently focused wins")
assert.equal(L.pickWindow(clients, ["discord"]), "", "no window -> nothing")
assert.equal(L.pickWindow(clients, ["", "ab"]), "", "too short to match safely")
assert.equal(L.pickWindow([{ class: "evil", address: '0x1" }) os.exit(' }], ["evil"]), "", "address is validated")

const now = 10_000_000
assert.equal(L.relTime(now - 5000, now), "now")
assert.equal(L.relTime(now - 125_000, now), "2m")
assert.equal(L.relTime(now - 2 * 3600_000, now), "2h")

assert.equal(L.timeoutMs(-1, false), 5000)
assert.equal(L.timeoutMs(3000, false), 3000)
assert.equal(L.timeoutMs(0, false), 0)
assert.equal(L.timeoutMs(-1, true), 0, "critical stays")

assert.equal(L.cleanBody('hi <b>x</b><IMG src="http://t/x.png"/>'), "hi <b>x</b>")
assert.equal(L.barState(3, 5, false).class, "unread")
assert.equal(L.barState(3, 5, true).class, "dnd")
assert.equal(L.barState(0, 0, false).class, "none")
console.log("selftest ok")
