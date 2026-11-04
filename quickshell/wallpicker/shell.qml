// Wallpaper carousel, launched on demand by hypr/wallpaper.sh and gone once closed (no idle cost).
// Arrows / wheel / click move, Enter or clicking the selected one applies, Esc or clicking outside closes.
// Input comes from wallpaper.sh: WALLPICKER_FILES (newline list), _CURRENT, _THUMBS, _ACCENT, _SET.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property var files: Quickshell.env("WALLPICKER_FILES").split("\n").filter(f => f !== "")
    readonly property string thumbs: Quickshell.env("WALLPICKER_THUMBS")
    readonly property color accent: "#" + (Quickshell.env("WALLPICKER_ACCENT") || "cc9166")

    function fileName(path) { return path.split("/").pop() }

    function apply(path) {
        run.command = [Quickshell.env("WALLPICKER_SET"), "set", path]
        run.startDetached() // the wallpaper process animates; this one can go right away
        Qt.quit()
    }

    Process { id: run }

    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-wallpicker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#6625222a" // dim the desktop behind the panel

        MouseArea { anchors.fill: parent; onClicked: Qt.quit() } // click outside closes

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 1120)
            height: 300
            color: "#f025222a"
            border.color: root.accent
            border.width: 2

            MouseArea { anchors.fill: parent } // clicks inside don't close

            ListView {
                id: list
                anchors { fill: parent; margins: 20; bottomMargin: 46 }
                orientation: ListView.Horizontal
                spacing: 12
                model: root.files
                interactive: false // wheel is handled below, one wallpaper per notch
                keyNavigationEnabled: true // defaults to `interactive`, which would kill the arrow keys
                clip: true
                keyNavigationWraps: true
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - 160
                preferredHighlightEnd: width / 2 + 160
                highlightMoveDuration: 220

                Keys.onReturnPressed: root.apply(root.files[currentIndex])
                Keys.onEnterPressed: root.apply(root.files[currentIndex])
                Keys.onEscapePressed: Qt.quit()

                Component.onCompleted: {
                    currentIndex = Math.max(0, root.files.indexOf(Quickshell.env("WALLPICKER_CURRENT")))
                    positionViewAtIndex(currentIndex, ListView.Center)
                    forceActiveFocus()
                }

                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem
                    width: 320
                    height: list.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: 320
                        height: 180
                        color: "#302c36"
                        border.color: card.selected ? root.accent : "transparent"
                        border.width: 3
                        scale: card.selected ? 1.0 : 0.8
                        opacity: card.selected ? 1.0 : 0.5
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 220 } }

                        Image {
                            anchors { fill: parent; margins: 3 }
                            source: "file://" + root.thumbs + "/" + root.fileName(card.modelData) + ".jpg"
                            sourceSize: Qt.size(480, 270)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.selected ? root.apply(card.modelData) : list.currentIndex = card.index
                    }
                }

                WheelHandler {
                    property real acc: 0 // touchpads send many small deltas; step once per notch's worth
                    onWheel: event => {
                        acc += event.angleDelta.y + event.angleDelta.x
                        while (acc <= -120) { list.incrementCurrentIndex(); acc += 120 }
                        while (acc >= 120) { list.decrementCurrentIndex(); acc -= 120 }
                    }
                }
            }

            Text {
                anchors { bottom: parent.bottom; bottomMargin: 14; horizontalCenter: parent.horizontalCenter }
                text: list.currentIndex >= 0 ? root.fileName(root.files[list.currentIndex]).replace(/\.[^.]+$/, "") : ""
                color: "#c6c0b9"
                font.family: "Inconsolata Nerd Font"
                font.pixelSize: 15
            }
        }
    }
}
