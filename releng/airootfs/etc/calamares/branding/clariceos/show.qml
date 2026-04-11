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
            text: qsTr("Instalando ClariceOS... não desligue o computador.")
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
                text: qsTr("Bem-vindo ao instalador do ClariceOS")
                font.pixelSize: 26
                font.bold: true
                color: "#97d3e8"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Dica: primeiro escolha seu perfil de uso e depois selecione o ambiente gráfico (DE).")
                font.pixelSize: 16
                color: "#ffffff"
            }
        }
    }
}
