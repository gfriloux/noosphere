// Carte DIFF DE CLOSURE (v0.2.0). Pilotée par le service Closure (`service`) : bouton de
// prévisualisation (idle), spinner (build/diff), résumé + console des changements (ready),
// message d'erreur (error). Lecture seule : le bouton build sans activer (cf. DESIGN.md).
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../model/closure.js" as Closure

Rectangle {
    id: card

    property var service

    readonly property var diff: service ? service.diff : null
    readonly property string status: service ? service.status : "idle"
    readonly property bool isError: status === "error"
    readonly property string cardSev: diff ? Closure.cardSeverity(diff.entries) : "neutral"
    readonly property string accent: isError ? "#f38ba8" : (cardSev === "reboot" ? "#fab387" : "#89b4fa")

    width: parent.width
    radius: 13
    color: "#313244"
    implicitHeight: col.implicitHeight + 28

    // Liseré gauche inséré (épouse les coins arrondis).
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 13
        anchors.bottomMargin: 13
        width: 3
        radius: 1.5
        color: card.isError ? "#f38ba8" : (card.cardSev === "reboot" ? "#fab387" : "#45475a")
    }

    Column {
        id: col
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 14
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 9

        // En-tête de carte.
        Item {
            width: parent.width
            height: 20

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "deployed_code"
                    size: Theme.fontSizeSmall
                    color: card.accent
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DIFF DE CLOSURE"
                    font.family: Theme.defaultMonoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4
                    color: card.accent
                }
            }

            // Statut à droite (build… / diff… / erreur).
            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: card.status !== "idle" && card.status !== "ready"
                text: {
                    switch (card.status) {
                    case "resolving":
                        return "résolution de l'hôte…";
                    case "building":
                        return "build…";
                    case "diffing":
                        return "diff…";
                    case "error":
                        return "échec";
                    default:
                        return "";
                    }
                }
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: card.isError ? "#f38ba8" : "#cba6f7"
            }
        }

        // Nombre d'inputs en retard à prévisualiser (overrides vers l'amont).
        readonly property int updateCount: (card.service && card.service.overrides) ? card.service.overrides.length : 0

        // --- idle, rien à mettre à jour : note ---
        StyledText {
            visible: card.status === "idle" && col.updateCount === 0
            width: parent.width
            text: "aucun input en retard — rien à prévisualiser"
            font.pixelSize: Theme.fontSizeSmall
            color: "#6c7086"
        }

        // --- idle : bouton de prévisualisation (build de la config mise à jour, à la demande) ---
        Rectangle {
            visible: card.status === "idle" && col.updateCount > 0
            width: parent.width
            height: 34
            radius: 9
            color: previewArea.containsMouse ? "#1e1e2e" : "#181825"
            border.width: 1
            border.color: previewArea.containsMouse ? "#89b4fa" : "#45475a"

            Row {
                anchors.centerIn: parent
                spacing: 7

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "deployed_code"
                    size: Theme.fontSizeSmall
                    color: "#89b4fa"
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "prévisualiser la mise à jour (" + col.updateCount + ")"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: "#89b4fa"
                }
            }
            MouseArea {
                id: previewArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (card.service)
                    card.service.preview()
            }
        }

        // --- building / diffing / resolving : spinner + libellé ---
        Row {
            visible: card.service && card.service.busy
            spacing: 8

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "progress_activity"
                size: Theme.fontSizeLarge
                color: "#cba6f7"

                RotationAnimation on rotation {
                    running: card.service && card.service.busy
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                }
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: card.status === "building" ? "build de la config mise à jour (sans activation)…" : (card.status === "diffing" ? "calcul du diff de closure…" : "résolution de l'hôte…")
                font.pixelSize: Theme.fontSizeSmall
                color: "#a6adc8"
            }
        }

        // --- error : message + réessayer ---
        StyledText {
            visible: card.isError
            width: parent.width
            text: card.service ? card.service.errorMessage : ""
            wrapMode: Text.WordWrap
            font.family: Theme.defaultMonoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: "#f38ba8"
        }
        Rectangle {
            visible: card.isError
            width: retryRow.implicitWidth + 20
            height: 24
            radius: 7
            color: retryArea.containsMouse ? "#1e1e2e" : "transparent"
            border.width: 1
            border.color: retryArea.containsMouse ? "#f38ba8" : "#45475a"

            Row {
                id: retryRow
                anchors.centerIn: parent
                spacing: 5

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "refresh"
                    size: Theme.fontSizeSmall
                    color: "#f38ba8"
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "réessayer"
                    font.pixelSize: Theme.fontSizeSmall
                    color: "#f38ba8"
                }
            }
            MouseArea {
                id: retryArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (card.service)
                    card.service.preview()
            }
        }

        // --- ready : résumé + console ---
        Row {
            visible: card.status === "ready" && card.diff
            spacing: 6

            StyledText {
                text: (card.diff ? card.diff.updated : 0) + " màj"
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: "#f9e2af"
            }
            StyledText {
                text: "· " + (card.diff ? card.diff.added : 0) + " ajoutés"
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: "#a6e3a1"
            }
            StyledText {
                text: "· " + (card.diff ? card.diff.removed : 0) + " retirés"
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: "#f38ba8"
            }
            StyledText {
                visible: card.diff && card.diff.sizeDelta.length > 0
                text: "· Δ " + (card.diff ? card.diff.sizeDelta : "")
                font.family: Theme.defaultMonoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: "#fab387"
            }
        }

        // Console des changements (scroll si longue).
        Rectangle {
            visible: card.status === "ready" && card.diff && card.diff.entries.length > 0
            width: parent.width
            radius: 9
            color: "#181825"
            implicitHeight: Math.min(entries.contentHeight, 240) + 16

            ListView {
                id: entries
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: card.diff ? card.diff.entries : []
                spacing: 3

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property bool reboot: modelData.severity === "reboot"

                    width: ListView.view ? ListView.view.width : 0
                    height: 18

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // Marqueur ▲ (reboot) ou espace d'alignement.
                        StyledText {
                            width: 10
                            text: row.reboot ? "▲" : ""
                            font.family: Theme.defaultMonoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#fab387"
                        }
                        StyledText {
                            text: row.modelData.name
                            font.family: Theme.defaultMonoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: row.reboot ? "#fab387" : "#cdd6f4"
                        }
                        StyledText {
                            visible: row.modelData.kind === "changed"
                            text: row.modelData.from + "  →  " + row.modelData.to
                            font.family: Theme.defaultMonoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#6c7086"
                        }
                        StyledText {
                            visible: row.modelData.kind === "added"
                            text: "ajouté"
                            font.family: Theme.defaultMonoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#a6e3a1"
                        }
                        StyledText {
                            visible: row.modelData.kind === "removed"
                            text: "retiré"
                            font.family: Theme.defaultMonoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#f38ba8"
                        }
                    }

                    // Badge REBOOT à droite.
                    Rectangle {
                        visible: row.reboot
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 15
                        width: rebootText.implicitWidth + 10
                        radius: 5
                        color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.14)

                        StyledText {
                            id: rebootText
                            anchors.centerIn: parent
                            text: "REBOOT"
                            font.family: Theme.defaultMonoFontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                            color: "#fab387"
                        }
                    }
                }
            }
        }

        // Relancer un aperçu quand un diff est déjà affiché.
        Rectangle {
            visible: card.status === "ready"
            width: rerunRow.implicitWidth + 20
            height: 24
            radius: 7
            color: rerunArea.containsMouse ? "#1e1e2e" : "transparent"
            border.width: 1
            border.color: rerunArea.containsMouse ? "#89b4fa" : "#45475a"

            Row {
                id: rerunRow
                anchors.centerIn: parent
                spacing: 5

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "refresh"
                    size: Theme.fontSizeSmall
                    color: "#89b4fa"
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "recalculer"
                    font.pixelSize: Theme.fontSizeSmall
                    color: "#89b4fa"
                }
            }
            MouseArea {
                id: rerunArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (card.service)
                    card.service.preview()
            }
        }
    }
}
