// Service de diff de closure (v0.2.0) : sur demande explicite, build le toplevel de la
// config NixOS du flake (SANS activation) puis `nvd diff` contre la génération courante.
// Lecture seule au sens DESIGN : construit/télécharge des dérivations, n'active jamais.
// Jamais automatique — aucun timer, uniquement déclenché par la vue via preview().
//
// Chaîne : (hostname si non configuré) → nix build …#toplevel --print-out-paths → nvd diff
// /run/current-system <toplevel> → parseNvdDiff. Best-effort : tout échec → status error,
// dernier diff connu conservé.
import QtQuick
import Quickshell.Io
import "../query/queries.js" as Queries
import "../model/closure.js" as Model

QtObject {
    id: root

    // --- Config (injectée par le widget) ---
    property string flakePath: ""
    property string host: "" // clé de nixosConfigurations ; vide → résolu via `hostname`
    // Inputs en retard à pointer sur leur amont (--override-input) : liste { name, ref }.
    // Vide → build du lock tel quel. Non vide → aperçu de mise à jour (sans écrire le lock).
    property var overrides: []

    // --- Sortie ---
    // idle | resolving | building | diffing | ready | error
    property string status: "idle"
    property var diff: null // modèle parseNvdDiff (ou null tant qu'aucun aperçu)
    property string errorMessage: ""

    readonly property bool configured: flakePath.length > 0
    readonly property bool busy: status === "resolving" || status === "building" || status === "diffing"

    // --- Interne ---
    property string _host: ""
    property string _target: "" // store path du toplevel buildé
    property string _stderr: "" // dernière sortie d'erreur (best-effort)

    // Déclenche un aperçu frais (build + diff). Point d'entrée unique de la vue.
    function preview() {
        if (!root.configured || root.busy)
            return;
        root.errorMessage = "";
        root._stderr = "";
        root._host = root.host;
        if (root._host.length > 0) {
            root._build();
        } else {
            root.status = "resolving";
            hostProc.running = true;
        }
    }

    function _build() {
        root.status = "building";
        buildProc.command = ["nix"].concat(Queries.buildToplevel(root.flakePath, root._host, root.overrides));
        buildProc.running = true;
    }

    function _fail(msg) {
        root.status = "error";
        root.errorMessage = msg;
    }

    // Résolution best-effort de l'hôte courant.
    property Process hostProc: Process {
        running: false
        command: Queries.hostnameArgv()
        stdout: StdioCollector {
            onStreamFinished: {
                root._host = text.trim();
                if (root._host.length > 0)
                    root._build();
                else
                    root._fail("hostname introuvable");
            }
        }
        onExited: code => {
            if (code !== 0 && root.status === "resolving")
                root._fail("résolution du hostname échouée (code " + code + ")");
        }
    }

    // 1er étage : nix build du toplevel (sans activation).
    property Process buildProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onBuilt(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root._stderr = text.trim()
        }
        onExited: code => {
            if (code !== 0 && root.status === "building")
                root._fail(root._buildError());
        }
    }

    function _buildError() {
        // Dernière ligne de stderr (souvent la plus parlante), sinon message générique.
        var s = root._stderr.trim();
        if (s.length > 0) {
            var lines = s.split("\n");
            return lines[lines.length - 1].trim();
        }
        return "build du toplevel échoué (vérifier le flake et le hostname)";
    }

    function _onBuilt(text) {
        if (!text || !text.trim())
            return; // échec → onExited
        // --print-out-paths peut imprimer plusieurs lignes ; le toplevel est la dernière.
        var lines = text.trim().split("\n");
        root._target = lines[lines.length - 1].trim();
        if (!root._target)
            return;
        root.status = "diffing";
        nvdProc.command = ["nvd"].concat(Queries.nvdDiff("/run/current-system", root._target));
        nvdProc.running = true;
    }

    // 2e étage : nvd diff → parse.
    property Process nvdProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onDiff(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root._stderr = text.trim()
        }
        onExited: code => {
            if (code !== 0 && root.status === "diffing")
                root._fail("nvd diff échoué (code " + code + ")");
        }
    }

    function _onDiff(text) {
        if (!text || !text.trim()) {
            root._fail("nvd n'a produit aucune sortie");
            return;
        }
        root.diff = Model.parseNvdDiff(text);
        root.status = "ready";
    }
}
