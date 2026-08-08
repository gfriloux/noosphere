// Widget de barre noosphere (plugin DankMaterialShell).
// Badge d'état : glyphe rosace coloré par l'état de dérive + pastille compteur d'inputs en
// retard. Au clic, ouvre le cockpit (Cockpit.qml). Lecture seule : aucune mutation.
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../model/format.js" as Format

PluginComponent {
    id: root

    // Réglages lus de pluginData (cf. Settings.qml).
    readonly property string cfgFlakePath: (pluginData && pluginData.flakePath) ? pluginData.flakePath : ""
    readonly property string cfgRepoSlug: (pluginData && pluginData.repoSlug) ? pluginData.repoSlug : ""
    readonly property string cfgBranch: (pluginData && pluginData.branch) ? pluginData.branch : "main"
    readonly property string cfgToken: (pluginData && pluginData.githubToken) ? pluginData.githubToken : ""
    readonly property string cfgApiBase: (pluginData && pluginData.apiBase) ? pluginData.apiBase : ""
    readonly property int cfgIntervalMs: (pluginData && pluginData.checkMinutes > 0) ? pluginData.checkMinutes * 60000 : 3600000

    // Couleur du badge : gris si le check a échoué (dernière valeur connue conservée),
    // sinon couleur de l'état de dérive.
    readonly property string stateColor: svc.connectionStatus === "error" ? "#6c7086" : Format.stateColor(svc.barState)
    readonly property bool showBadge: svc.barState === "drift" && svc.behindCount > 0

    Noosphere {
        id: svc
        flakePath: root.cfgFlakePath
        githubToken: root.cfgToken
        apiBase: root.cfgApiBase
        intervalMs: root.cfgIntervalMs
    }

    // ---- Pièce de barre : glyphe rosace + pastille compteur ----
    horizontalBarPill: Component {
        Item {
            implicitWidth: glyph.implicitWidth + Theme.spacingXS
            implicitHeight: glyph.implicitHeight

            NoosphereGlyph {
                id: glyph
                anchors.centerIn: parent
                size: Theme.fontSizeLarge
                color: root.stateColor
            }

            // Pastille compteur d'inputs en retard, ancrée en haut-droite du glyphe.
            StyledRect {
                id: badge
                visible: root.showBadge
                anchors.horizontalCenter: glyph.right
                anchors.verticalCenter: glyph.top
                width: Math.max(badgeText.implicitWidth + Theme.spacingXS, height)
                height: badgeText.implicitHeight + 2
                radius: height / 2
                color: "#f9e2af"

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: svc.behindCount > 99 ? "99+" : String(svc.behindCount)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.background
                }
            }
        }
    }

    // ---- Popout : cockpit (Cockpit.qml) ----
    popoutContent: Component {
        Cockpit {
            service: svc
            owner: root
        }
    }
    popoutWidth: 440
    // Hauteur dérivée du contenu (calculée en amont, comme astropath/auspex : le popout est
    // dimensionné par le widget, jamais réécrit depuis le cockpit). padding 14×2 + carte
    // en-tête (~87) + gaps 11×2 + carte inputs (28 + titre 20 + N lignes×33) + pied 36.
    readonly property int inputCount: svc.inputs.length
    popoutHeight: 28 + 87 + 11 + (28 + 20 + Math.max(1, inputCount) * 33) + 11 + 36
}
