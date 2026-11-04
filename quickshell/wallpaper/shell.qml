// Resident wallpaper: draws the wallpaper on the background layer and animates changes
// (circle growing from the center). Idle = no timers or animations; nothing redraws until a switch.
//   qs -c wallpaper -d                                   start (Hyprland autostart)
//   qs -c wallpaper ipc call wallpaper set /path/img     switch with transition
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // Saved by wallpaper.sh; Image follows the symlink.
    property string current: "file://" + Quickshell.env("HOME") + "/.local/state/wallpaper/current"

    IpcHandler {
        target: "wallpaper"
        function set(path: string): void {
            root.current = "file://" + path
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "qs-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#25222a"

            // Idle: the plain image plus an idle (empty) effect; nothing redraws until a switch.
            property bool busy: false

            function go(src) {
                if (grow.running) { grow.stop(); settle() } // jump to the newest target
                if (src === shown.source.toString()) { incoming.source = ""; busy = false; return }
                busy = true // a switch is in progress
                incoming.source = src // transition starts once it has loaded
            }

            function settle() {
                shown.source = incoming.source // already decoded at the same size: instant
                incoming.source = "" // free the second copy
                mask.r = 0
                busy = false
            }

            Component.onCompleted: shown.source = root.current // not a binding: changes go through go()

            Connections {
                target: root
                function onCurrentChanged() { win.go(root.current) }
            }

            Image {
                id: shown
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(win.width, win.height) // never keep more pixels than the screen
                asynchronous: false // swap from the shared cache must land in the same frame
                cache: true
            }

            Image {
                id: incoming
                anchors.fill: parent
                visible: false // drawn through the mask effect only
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(win.width, win.height)
                asynchronous: true
                cache: true
                onStatusChanged: {
                    if (status === Image.Ready && win.busy) grow.restart()
                    else if (status === Image.Error) { source = ""; win.busy = false } // unreadable: keep current
                }
            }

            Item {
                id: mask
                anchors.fill: parent
                visible: false
                // Must exist from startup: toggling it on for a switch leaves the first transitions undrawn.
                // Quarter resolution is plenty for a soft-edged circle (~0.5 MB instead of ~8 MB).
                layer.enabled: true
                layer.textureSize: Qt.size(win.width / 4, win.height / 4)
                layer.smooth: true
                property real r: 0
                Rectangle {
                    x: mask.width / 2 - mask.r
                    y: mask.height / 2 - mask.r
                    width: mask.r * 2
                    height: width
                    radius: mask.r
                }
            }

            MultiEffect {
                anchors.fill: parent
                visible: true // same reason; with no incoming image it draws nothing at idle
                source: incoming
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0 // soft edge on the circle
            }

            NumberAnimation {
                id: grow
                target: mask
                property: "r"
                from: 0
                to: Math.hypot(win.width, win.height) / 2
                duration: 800
                easing.type: Easing.OutCubic
                onFinished: win.settle()
            }
        }
    }
}
