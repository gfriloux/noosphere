// noosphere's bar widget (a DankMaterialShell plugin).
// Status badge: a rosette glyph coloured by the drift state + a pill counting the inputs
// that are behind. Clicking opens the cockpit (Cockpit.qml). Read-only: no mutation.
//
// `ComponentBehavior: Bound`: the two Components below (bar pill, popout) are instantiated
// by DMS, not by us, so they cannot be given `required property` values — the instantiator
// knows nothing about them. The pragma captures the enclosing component's ids (`root`,
// `svc`, `closureSvc`) instead of resolving them dynamically, which is exactly what this
// code means. There is no model delegate in this file, so the pragma has no other semantics
// to change here.
pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../model/format.js" as Format
import "../query/queries.js" as Queries

PluginComponent {
    id: root

    // Settings read from pluginData (see Settings.qml).
    readonly property string cfgFlakePath: (pluginData && pluginData.flakePath) ? pluginData.flakePath : ""
    readonly property string cfgRepoSlug: (pluginData && pluginData.repoSlug) ? pluginData.repoSlug : ""
    readonly property string cfgBranch: (pluginData && pluginData.branch) ? pluginData.branch : "main"
    readonly property string cfgToken: (pluginData && pluginData.githubToken) ? pluginData.githubToken : ""
    readonly property string cfgApiBase: (pluginData && pluginData.apiBase) ? pluginData.apiBase : ""
    readonly property int cfgIntervalMs: (pluginData && pluginData.checkMinutes > 0) ? pluginData.checkMinutes * 60000 : 3600000
    readonly property string cfgHost: (pluginData && pluginData.hostname) ? pluginData.hostname : ""

    // Badge colour: grey when the check failed — the last known value is kept — otherwise
    // the drift state's colour.
    readonly property string stateColor: svc.connectionStatus === "error" ? "#6c7086" : Format.stateColor(svc.barState)
    readonly property bool showBadge: svc.barState === "drift" && svc.behindCount > 0

    Noosphere {
        id: svc
        flakePath: root.cfgFlakePath
        githubToken: root.cfgToken
        apiBase: root.cfgApiBase
        intervalMs: root.cfgIntervalMs
    }

    // Inputs that are behind → overrides onto upstream (update preview, without writing the lock).
    readonly property var closureOverrides: {
        var out = [];
        var ins = svc.inputs;
        for (var i = 0; i < ins.length; i++) {
            var it = ins[i];
            if (it.type === "github" && typeof it.behind === "number" && it.behind > 0 && it.owner && it.head)
                out.push({
                    "name": it.name,
                    "ref": Queries.githubFlakeRef(it.owner, it.repoName, it.head)
                });
        }
        return out;
    }

    // Closure-diff service (built on demand, never automatically).
    Closure {
        id: closureSvc
        flakePath: root.cfgFlakePath
        host: root.cfgHost
        overrides: root.closureOverrides
    }

    // ---- Bar pill: rosette glyph + counter pill ----
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

            // Pill counting the inputs that are behind, anchored top-right of the glyph.
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

    // ---- Popout: the cockpit (Cockpit.qml) ----
    popoutContent: Component {
        Cockpit {
            service: svc
            closureService: closureSvc
            owner: root
        }
    }
    popoutWidth: 480
    // Height derived from the content, computed here as in astropath/auspex: the popout is
    // sized by the widget and never resized from inside the cockpit. padding 14×2 + header
    // card (~87) + gaps 11×3 + inputs card (28 + title 20 + N×33) + closure card + footer 36.
    readonly property int inputCount: svc.inputs.length
    readonly property int closureCount: (closureSvc.diff && closureSvc.diff.entries) ? closureSvc.diff.entries.length : 0
    // Closure card: roughly title + (button | spinner | summary+console) depending on state.
    readonly property int closureH: closureSvc.status === "ready" ? (28 + 20 + 9 + 20 + 9 + Math.min(closureCount * 21, 240) + 16 + 9 + 24) : (closureSvc.status === "error" ? (28 + 20 + 9 + 48 + 9 + 24) : (28 + 20 + 9 + 34))
    popoutHeight: 28 + 87 + 11 + (28 + 20 + Math.max(1, inputCount) * 33) + 11 + closureH + 11 + 36
}
