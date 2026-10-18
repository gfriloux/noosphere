// Closure-diff service (v0.2.0): on explicit request, builds the flake's NixOS
// configuration toplevel (WITHOUT activating it) then runs `nvd diff` against the current
// generation. Read-only in DESIGN's sense: it builds and downloads derivations, it never
// activates. Never automatic — no timer, triggered only by the view through preview().
//
// The chain: (hostname when unconfigured) → nix build …#toplevel --print-out-paths →
// nvd diff /run/current-system <toplevel> → parseNvdDiff. Best-effort: any failure sets the
// status to error and keeps the last known diff.
import QtQuick
import Quickshell.Io
import "../query/queries.js" as Queries
import "../model/closure.js" as Model

QtObject {
    id: root

    // --- Config, injected by the widget ---
    property string flakePath: ""
    property string host: "" // clé de nixosConfigurations ; vide → résolu via `hostname`
    // Inputs that are behind, to point at their upstream (--override-input): a list of
    // { name, ref }. Empty → build the lock as it stands. Non-empty → an update preview,
    // without writing the lock.
    property var overrides: []

    // --- Output ---
    // idle | resolving | building | diffing | ready | error
    property string status: "idle"
    property var diff: null // modèle parseNvdDiff (ou null tant qu'aucun aperçu)
    property string errorMessage: ""

    readonly property bool configured: flakePath.length > 0
    readonly property bool busy: status === "resolving" || status === "building" || status === "diffing"

    // --- Internal ---
    property string _host: ""
    property string _target: "" // store path du toplevel buildé
    property string _stderr: "" // dernière sortie d'erreur (best-effort)

    // Triggers a fresh preview (build + diff). The view's only entry point.
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

    // Best-effort resolution of the current host.
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
        // qmllint disable signal-handler-parameters
        // `exited(int, QProcess::ExitStatus)`: the second parameter is a C++ enum Quickshell
        // does not register for QML, so qmllint cannot resolve it and warns on every such
        // handler. Nothing in this repository can fix that. The same pair guards the two
        // other `onExited` handlers below. Remove all three once Quickshell exposes
        // ExitStatus in its qmltypes.
        onExited: code => {
            if (code !== 0 && root.status === "resolving")
                root._fail("résolution du hostname échouée (code " + code + ")");
        }
        // qmllint enable signal-handler-parameters
    }

    // Stage 1: nix build of the toplevel, without activating it.
    property Process buildProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onBuilt(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root._stderr = text.trim()
        }
        // qmllint disable signal-handler-parameters
        onExited: code => {
            if (code !== 0 && root.status === "building")
                root._fail(root._buildError());
        }
        // qmllint enable signal-handler-parameters
    }

    function _buildError() {
        // The last stderr line, usually the most telling one; otherwise a generic message.
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
        // --print-out-paths can print several lines; the toplevel is the last one.
        var lines = text.trim().split("\n");
        root._target = lines[lines.length - 1].trim();
        if (!root._target)
            return;
        root.status = "diffing";
        nvdProc.command = ["nvd"].concat(Queries.nvdDiff("/run/current-system", root._target));
        nvdProc.running = true;
    }

    // Stage 2: nvd diff → parse.
    property Process nvdProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onDiff(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root._stderr = text.trim()
        }
        // qmllint disable signal-handler-parameters
        onExited: code => {
            if (code !== 0 && root.status === "diffing")
                root._fail("nvd diff échoué (code " + code + ")");
        }
        // qmllint enable signal-handler-parameters
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
