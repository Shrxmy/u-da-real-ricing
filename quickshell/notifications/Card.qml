// One popup: a tiny retro window (accent title bar, hard pixel shadow). Rose instead of accent when critical.
import QtQuick
import Quickshell.Services.Notifications
import "lib.js" as L

Item {
    id: card

    required property var n // Notification; null once it's closed (during the fade-out)
    required property color accent
    required property color sand
    required property real arrived
    required property real now
    required property int token // bumped when the app replaces the notification: timer starts over

    signal activated()
    signal closeClicked()
    signal timedOut()
    signal actionClicked(var action)

    readonly property bool critical: n ? n.urgency === NotificationUrgency.Critical : false
    readonly property color edge: critical ? "#a97070" : accent
    readonly property string img: n ? L.imageSource(n.image, n.appIcon) : ""
    readonly property var buttons: n ? Array.from(n.actions).filter(a => a.identifier !== "default") : []
    readonly property int progress: n && n.hints && n.hints.value !== undefined ? Math.max(0, Math.min(100, n.hints.value)) : -1

    implicitHeight: frame.height + 4

    // (re)start the countdown; hovering holds it, and critical / timeout 0 never count down
    function arm() {
        life.stop()
        if (life.interval > 0 && !hover.hovered) life.start()
    }
    onTokenChanged: arm()
    Component.onCompleted: arm()

    Timer {
        id: life
        interval: card.n ? L.timeoutMs(card.n.expireTimeout, card.critical) : 0
        onIntervalChanged: card.arm()
        onTriggered: card.timedOut()
    }

    HoverHandler { id: hover; onHoveredChanged: card.arm() }

    Rectangle { x: 4; y: 4; width: frame.width; height: frame.height; color: "#141216" } // pixel shadow

    Rectangle {
        id: frame
        width: card.width - 4
        height: content.implicitHeight + 4
        color: "#25222a"
        border.color: card.edge
        border.width: 2

        MouseArea { anchors.fill: parent; onClicked: card.activated() } // the whole card goes to the app

        Column {
            id: content
            x: 2; y: 2
            width: parent.width - 4

            Rectangle { // title bar
                width: parent.width
                height: 20
                color: card.edge

                Text {
                    anchors { left: parent.left; leftMargin: 8; right: close.left; verticalCenter: parent.verticalCenter }
                    text: (card.n && card.n.appName ? card.n.appName : "notification") + " · " + L.relTime(card.arrived, card.now)
                    color: "#25222a"
                    font { family: "Inconsolata Nerd Font"; pixelSize: 11; bold: true; capitalization: Font.AllUppercase; letterSpacing: 0.7 }
                    elide: Text.ElideRight
                }
                Text {
                    id: close
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: "×"
                    color: "#25222a"
                    font { family: "Inconsolata Nerd Font"; pixelSize: 14; bold: true }
                    MouseArea { anchors { fill: parent; margins: -4 } onClicked: card.closeClicked() }
                }
            }

            Item {
                width: parent.width
                height: row.implicitHeight + 16

                Row {
                    id: row
                    x: 10; y: 8
                    width: parent.width - 20
                    spacing: 10

                    Image {
                        visible: card.img !== ""
                        source: card.img
                        width: 46; height: 46
                        sourceSize: Qt.size(92, 92)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Column {
                        width: row.width - (card.img !== "" ? 56 : 0)
                        spacing: 2

                        Text {
                            width: parent.width
                            text: card.n ? card.n.summary : ""
                            color: card.critical ? "#a97070" : card.sand
                            font { family: "Inconsolata Nerd Font"; pixelSize: 14; bold: true }
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.n ? L.cleanBody(card.n.body) : ""
                            textFormat: Text.StyledText
                            color: "#c6c0b9"
                            font { family: "Inconsolata Nerd Font"; pixelSize: 13 }
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }

                        Item { // progress: dashed accent fill in a thin frame
                            visible: card.progress >= 0
                            width: parent.width
                            height: 14
                            Rectangle {
                                id: track
                                y: 6; width: parent.width; height: 6
                                color: "transparent"
                                border.color: "#4d4d4d"
                                Item {
                                    x: 1; y: 1; height: 4
                                    width: (parent.width - 2) * card.progress / 100
                                    clip: true
                                    Row {
                                        spacing: 2
                                        Repeater {
                                            model: Math.max(0, Math.ceil(track.width / 8))
                                            Rectangle { width: 6; height: 4; color: card.edge }
                                        }
                                    }
                                }
                            }
                        }

                        Row { // action buttons, only when the app sent some
                            visible: card.buttons.length > 0
                            topPadding: 6
                            spacing: 8
                            Repeater {
                                model: card.buttons
                                Item {
                                    required property var modelData
                                    required property int index
                                    width: label.implicitWidth + 20
                                    height: 20
                                    Rectangle { x: 2; y: 2; width: parent.width; height: parent.height; color: "#141216" }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: index === 0 ? card.sand : "#4d4d4d"
                                        Text {
                                            id: label
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: index === 0 ? "#25222a" : "#c6c0b9"
                                            font { family: "Inconsolata Nerd Font"; pixelSize: 12 }
                                        }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: card.actionClicked(modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
