/* ClariceOS Calamares slideshow */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide()
    }

    Timer {
        id: advanceTimer
        interval: 6000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        anchors.fill: parent

        Image {
            source: "welcome.png"
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit
            width: parent.width * 0.6
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            text: qsTr("Installing Clarice OS — please wait…")
            font.pixelSize: 18
            color: "#ffffff"
        }
    }

    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#1a1a2e"
        }

        Column {
            anchors.centerIn: parent
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Welcome to Clarice OS")
                font.pixelSize: 26
                font.bold: true
                color: "#97d3e8"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("A modern Arch Linux-based operating system.")
                font.pixelSize: 16
                color: "#ffffff"
            }
        }
    }
}
