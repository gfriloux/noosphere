// noosphere's cockpit — the popout's content (read-only).
// Stacked cards: a header (flake identity + branch + generation + last check) and INPUTS
// (the direct inputs, their lag against upstream, a changelog link on hover). Footer: the
// poll interval + a manual re-check, read-only. Mutations (update, rebuild, rollback) and
// the rebuild card are deferred (see DESIGN.md).
//
// Decoupled from NoosphereWidget: it receives the service (`service`) and the root
// component (`owner`). It never builds or runs a command.
//
// `ComponentBehavior: Bound`: the Repeater's delegate already declares
// `required property var modelData`, so the pragma changes nothing for it — it only makes
// the capture of the `cockpit` id from inside the delegate explicit.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../model/format.js" as Format

PopoutComponent {
    id: cockpit

    property var service
    property var closureService
    property var owner

    // PopoutComponent's default header is hidden: we carry our own cards.
    headerText: ""

    readonly property bool isError: service && service.connectionStatus === "error"
    readonly property var inputs: service ? service.inputs : []

    // A coarse clock to refresh the relative ages; they move slowly.
    property double now: Date.now() / 1000
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: cockpit.now = Date.now() / 1000
    }

    // Wrapper: DMS stacks a PopoutComponent's content in a Column, which forbids anchors on
    // its direct children. So we place a single Item (width + height, no anchors); inside
    // it, our own Column can anchor freely.
    Item {
        width: parent.width
        height: outer.implicitHeight + 28

        Column {
            id: outer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 14
            spacing: 11

            // ============ Header card ============
            Rectangle {
                width: parent.width
                radius: 13
                color: "#313244"
                implicitHeight: headerCol.implicitHeight + 28

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 13
                    anchors.bottomMargin: 13
                    width: 3
                    radius: 1.5
                    color: "#89b4fa"
                }

                Column {
                    id: headerCol
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 14
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    spacing: 9

                    // Row 1: glyph + identity, branch chip on the right.
                    Item {
                        width: parent.width
                        height: 34

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            NoosphereGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 22
                                color: "#89b4fa"
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                StyledText {
                                    text: "noosphere"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: "#cdd6f4"
                                }
                                StyledText {
                                    text: cockpit.owner ? cockpit.owner.cfgRepoSlug : ""
                                    visible: text.length > 0
                                    font.family: Theme.defaultMonoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: "#89b4fa"
                                }
                            }
                        }

                        // Branch chip.
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22
                            width: branchRow.implicitWidth + 18
                            radius: 11
                            color: "#1e1e2e"
                            border.width: 1
                            border.color: "#45475a"

                            Row {
                                id: branchRow
                                anchors.centerIn: parent
                                spacing: 5

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "fork_right"
                                    size: Theme.fontSizeSmall
                                    color: "#a6adc8"
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: cockpit.owner ? cockpit.owner.cfgBranch : "main"
                                    font.family: Theme.defaultMonoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: "#a6adc8"
                                }
                            }
                        }
                    }

                    // Row 2: generation on the left, last check on the right.
                    Item {
                        width: parent.width
                        height: 16

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: "#a6e3a1"
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: cockpit.service && cockpit.service.generation > 0 ? ("génération n°" + cockpit.service.generation + " · activée " + Format.relativeAge(cockpit.service.generationActivatedAt, cockpit.now)) : "génération courante inconnue"
                                font.pixelSize: Theme.fontSizeSmall
                                color: "#a6adc8"
                            }
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: cockpit.service && cockpit.service.lastCheck > 0 ? ("check amont · " + Format.relativeAge(cockpit.service.lastCheck, cockpit.now)) : "check amont · en attente…"
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#6c7086"
                        }
                    }
                }
            }

            // ============ INPUTS card ============
            Rectangle {
                width: parent.width
                radius: 13
                color: "#313244"
                implicitHeight: inputsCol.implicitHeight + 28

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 13
                    anchors.bottomMargin: 13
                    width: 3
                    radius: 1.5
                    color: cockpit.isError ? "#f38ba8" : "#f9e2af"
                }

                Column {
                    id: inputsCol
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 14
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    spacing: 3

                    // Card header.
                    Item {
                        width: parent.width
                        height: 20

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "download"
                                size: Theme.fontSizeSmall
                                color: "#f9e2af"
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "INPUTS"
                                font.family: Theme.defaultMonoFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.4
                                color: "#f9e2af"
                            }
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: cockpit.service ? (cockpit.service.behindCount + " en retard · " + cockpit.service.upToDateCount + " à jour") : ""
                            font.family: Theme.defaultMonoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#f9e2af"
                        }
                    }

                    // Error status row; best-effort, the list below stays the last known state.
                    StyledText {
                        width: parent.width
                        visible: cockpit.isError
                        text: "échec du check · réessayer"
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#f38ba8"
                    }

                    // The direct inputs.
                    Repeater {
                        model: cockpit.inputs

                        delegate: Item {
                            id: row

                            required property var modelData
                            readonly property bool behindPositive: typeof modelData.behind === "number" && modelData.behind > 0
                            readonly property string changelogUrl: (row.modelData.owner && row.modelData.head) ? Format.compareWebUrl(row.modelData.owner, row.modelData.repoName, row.modelData.lockRev, row.modelData.head) : ""

                            width: parent.width
                            height: 30

                            HoverHandler {
                                id: rowHover
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#ffffff"
                                opacity: rowHover.hovered ? 0.045 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    // A layout-managed item sizes itself through its implicit
                                    // size; setting width/height directly is undefined
                                    // behaviour per Qt.
                                    implicitWidth: 7
                                    implicitHeight: 7
                                    radius: 3.5
                                    color: Format.inputDotColor(row.modelData.behind)
                                }
                                StyledText {
                                    text: row.modelData.name
                                    font.family: Theme.defaultMonoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: "#cdd6f4"
                                }
                                // Channel chip (e.g. nixos-unstable), hidden when absent.
                                Rectangle {
                                    visible: row.modelData.channel.length > 0
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitHeight: 16
                                    implicitWidth: chanText.implicitWidth + 12
                                    radius: 6
                                    color: "#1e1e2e"

                                    StyledText {
                                        id: chanText
                                        anchors.centerIn: parent
                                        text: row.modelData.channel
                                        font.family: Theme.defaultMonoFontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: "#6c7086"
                                    }
                                }
                                // Elastic, elidable lock age: it absorbs the missing room — long
                                // names, large counters — and pushes the lag to the right.
                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: "lock " + Format.relativeAge(row.modelData.lockedAt, cockpit.now)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: "#6c7086"
                                }

                                // Changelog link (read-only), revealed on hover of a row that is behind.
                                Rectangle {
                                    visible: row.behindPositive && row.changelogUrl.length > 0
                                    opacity: rowHover.hovered ? 1 : 0
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitHeight: 20
                                    implicitWidth: clText.implicitWidth + 16
                                    radius: 7
                                    color: clArea.containsMouse ? "#313244" : "#1e1e2e"
                                    border.width: 1
                                    border.color: clArea.containsMouse ? "#89b4fa" : "#45475a"

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 120
                                        }
                                    }

                                    StyledText {
                                        id: clText
                                        anchors.centerIn: parent
                                        text: "changelog"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: "#89b4fa"
                                    }
                                    MouseArea {
                                        id: clArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally(row.changelogUrl)
                                    }
                                }

                                // Lag text, a single line sized to its content, on the right.
                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    wrapMode: Text.NoWrap
                                    text: Format.behindLabel(row.modelData.behind)
                                    font.family: Theme.defaultMonoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: row.behindPositive ? "#f9e2af" : "#6c7086"
                                }
                            }
                        }
                    }
                }
            }

            // ============ Closure diff card ============
            ClosureCard {
                width: parent.width
                service: cockpit.closureService
                behindCount: cockpit.service ? cockpit.service.behindCount : 0
            }

            // ============ Footer: poll interval + manual re-check (read-only) ============
            Item {
                width: parent.width
                height: 36

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "schedule"
                        size: Theme.fontSizeSmall
                        color: "#6c7086"
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var ms = cockpit.service ? cockpit.service.intervalMs : 3600000;
                            return "cadence " + (ms >= 3600000 ? (Math.round(ms / 3600000) + " h") : (Math.round(ms / 60000) + " min"));
                        }
                        font.family: Theme.defaultMonoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#6c7086"
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    width: checkRow.implicitWidth + 26
                    radius: 9
                    color: checkArea.containsMouse ? "#a6c4fc" : "#89b4fa"

                    Row {
                        id: checkRow
                        anchors.centerIn: parent
                        spacing: 6

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "refresh"
                            size: Theme.fontSizeSmall
                            color: "#1e1e2e"

                            RotationAnimation on rotation {
                                running: cockpit.service && cockpit.service.connectionStatus === "polling"
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 900
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "check maintenant"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: "#1e1e2e"
                        }
                    }
                    MouseArea {
                        id: checkArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (cockpit.service)
                            cockpit.service.poll()
                    }
                }
            }
        }
    }
}
