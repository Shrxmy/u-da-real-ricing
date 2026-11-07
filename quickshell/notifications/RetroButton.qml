// Chunky button with a hard pixel shadow: sand when on, subtle when off.
import QtQuick

Item {
    id: btn
    property alias text: label.text
    property bool on: true
    required property color sand
    signal clicked()

    width: label.implicitWidth + 20
    height: 20

    Rectangle { x: 2; y: 2; width: parent.width; height: parent.height; color: "#141216" }
    Rectangle {
        anchors.fill: parent
        color: btn.on ? btn.sand : "#4d4d4d"
        Text {
            id: label
            anchors.centerIn: parent
            color: btn.on ? "#25222a" : "#c6c0b9"
            font { family: "Inconsolata Nerd Font"; pixelSize: 12 }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: btn.clicked() }
}
