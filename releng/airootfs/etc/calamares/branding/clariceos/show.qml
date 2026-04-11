/* ClariceOS Calamares slideshow — refreshed visual design */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide()
    }

    Timer {
        id: advanceTimer
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0b1220" }
                GradientStop { position: 1.0; color: "#131c2f" }
            }
        }

        Image {
            source: "welcome.png"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -24
            fillMode: Image.PreserveAspectFit
            width: parent.width * 0.50
            smooth: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 42
            width: parent.width * 0.72
            height: 64
            radius: 12
            color: "#1f2a44"
            opacity: 0.90

            Text {
                anchors.centerIn: parent
                text: qsTr("Instalando ClariceOS... não desligue o computador.")
                font.pixelSize: 19
                font.bold: true
                color: "#e5e7eb"
            }
        }
    }

    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0f172a" }
                GradientStop { position: 1.0; color: "#1e1b4b" }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: parent.height * 0.56
            radius: 14
            color: "#101827"
            opacity: 0.92
        }

        Column {
            anchors.centerIn: parent
            width: parent.width * 0.68
            spacing: 18

            Text {
                text: qsTr("Bem-vindo ao instalador do ClariceOS")
                font.pixelSize: 32
                font.bold: true
                color: "#f8fafc"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Text {
                text: qsTr("Design renovado, fluxo simplificado e instalação mais previsível.")
                font.pixelSize: 18
                color: "#cbd5e1"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Rectangle {
                width: parent.width
                height: 2
                color: "#334155"
                opacity: 0.9
            }

            Text {
                text: qsTr("Na etapa Pacotes, selecione o ambiente gráfico e os perfis opcionais de uso.")
                font.pixelSize: 17
                color: "#93c5fd"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }
    }
}
