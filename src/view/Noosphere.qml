// Service noosphere : lit le flake local (`nix flake metadata --json`), interroge l'amont
// GitHub (compare) pour chaque input, assemble le modèle de dérive et poll périodiquement.
// Lecture seule : aucun `nix flake update`, aucun `nixos-rebuild`.
//
// Pipeline d'un poll :
//   1. nix flake metadata --json <path>  → parseMetadata → inputs directs
//   2. pour chaque input github, séquentiellement :
//        head = channel, sinon default_branch (GET repo) ;
//        GET compare/<lockRev>...<head> → parseCompare → behind
//   3. mergeBehind → inputs annotés, barState/behindCount, lastCheck
//   4. (best-effort, en parallèle) readlink + stat du profil système → génération courante
//
// Le token GitHub (optionnel) est passé en header `Authorization: Bearer` par le service ;
// il n'entre jamais dans les couches query/model (cf. DESIGN.md).
import QtQuick
import Quickshell.Io
import "../query/queries.js" as Queries
import "../model/inputs.js" as Model

QtObject {
    id: root

    // --- Config (injectée par le widget depuis pluginData) ---
    property string flakePath: "" // chemin du flake local (ex. /etc/nixos)
    property string githubToken: "" // optionnel : lève la limite 60 req/h
    property string apiBase: "" // vide = api.github.com ; surchargé pour le mock dev
    property int intervalMs: 3600000 // cadence par défaut : 1 h

    // --- Sortie (modèle de domaine) ---
    property var inputs: [] // inputs annotés du retard (behind)
    property int behindCount: 0
    property int upToDateCount: 0
    property string barState: "uptodate" // uptodate | drift (| rebuilding, cap futur)
    // idle | polling | live | error
    property string connectionStatus: "idle"
    property string errorMessage: ""
    property double lastCheck: 0 // unix secondes
    property int generation: 0 // n° de génération système courante (0 = inconnu)
    property double generationActivatedAt: 0 // unix secondes (mtime du profil)

    readonly property bool configured: flakePath.length > 0

    // --- État interne du driver séquentiel ---
    property var _inputs: [] // inputs bruts (parseMetadata), avant retard
    property var _behind: ({}) // accumulateur name → behind
    property var _heads: ({}) // accumulateur name → head amont résolu (pour le lien changelog)
    property var _queue: [] // inputs github à comparer
    property int _cursor: 0
    property bool _busy: false

    // (Re)poll quand un réglage pertinent change.
    function reconfigure() {
        if (!root.configured) {
            root.connectionStatus = "idle";
            return;
        }
        poll();
    }
    onFlakePathChanged: reconfigure()
    onGithubTokenChanged: reconfigure()
    onApiBaseChanged: reconfigure()

    // ---- Poll ----

    function poll() {
        if (!root.configured || root._busy)
            return;
        root._busy = true;
        root.connectionStatus = "polling";
        metaProc.command = ["nix"].concat(Queries.flakeMetadata(root.flakePath));
        metaProc.running = true;
        // Génération courante : best-effort, indépendant du pipeline de dérive.
        genRevProc.running = true;
        genTimeProc.running = true;
    }

    // Argv curl pour un GET d'API GitHub (JSON). Le token, s'il existe, va en header.
    function _ghGet(url) {
        var cmd = ["curl", "-s", "--max-time", "10", "-H", "Accept: application/vnd.github+json", "-H", "X-GitHub-Api-Version: 2022-11-28", "-H", "User-Agent: noosphere"];
        if (root.githubToken.length > 0)
            cmd.push("-H", "Authorization: Bearer " + root.githubToken);
        cmd.push(url);
        return cmd;
    }

    // 1er étage : nix flake metadata.
    property Process metaProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onMeta(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("noosphere nix:", text.trim())
        }
        onExited: code => {
            if (code !== 0 && root._busy)
                root._fail("flake illisible (nix " + code + ")");
        }
    }

    function _onMeta(text) {
        if (!text || !text.trim())
            return; // échec → onExited
        var meta = root._parse(text);
        if (meta === null)
            return;
        root._inputs = Model.parseMetadata(meta);
        root._behind = {};
        root._heads = {};
        // File des inputs github (les autres types sont affichés, jamais comparés).
        var q = [];
        for (var i = 0; i < root._inputs.length; i++)
            if (root._inputs[i].type === "github" && root._inputs[i].owner && root._inputs[i].repoName)
                q.push(root._inputs[i]);
        root._queue = q;
        root._cursor = 0;
        root._next();
    }

    // ---- Driver séquentiel des compare ----

    function _next() {
        if (root._cursor >= root._queue.length) {
            root._commit();
            return;
        }
        var it = root._queue[root._cursor];
        if (it.channel) {
            root._compare(it, it.channel);
        } else {
            // Pas de ref suivie → résoudre la branche par défaut du repo d'abord.
            repoProc.command = root._ghGet(Queries.repoApiUrl(root.apiBase, it.owner, it.repoName));
            repoProc.running = true;
        }
    }

    property Process repoProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var it = root._queue[root._cursor];
                var res = root._parse(text);
                var head = res ? Model.parseDefaultBranch(res) : "";
                if (head)
                    root._compare(it, head);
                else
                    root._advance(); // non résolu → behind reste indéterminé
            }
        }
        onExited: code => {
            if (code !== 0)
                root._advance();
        }
    }

    function _compare(it, head) {
        root._heads[it.name] = head; // mémorisé pour le lien changelog de la vue
        cmpProc.command = root._ghGet(Queries.compareApiUrl(root.apiBase, it.owner, it.repoName, it.lockRev, head));
        cmpProc.running = true;
    }

    property Process cmpProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var it = root._queue[root._cursor];
                var res = root._parse(text);
                var b = res ? Model.parseCompare(res) : null;
                if (typeof b === "number")
                    root._behind[it.name] = b;
                root._advance();
            }
        }
        onExited: code => {
            if (code !== 0)
                root._advance();
        }
    }

    function _advance() {
        root._cursor += 1;
        root._next();
    }

    // ---- Aboutissement ----

    function _commit() {
        var list = Model.mergeBehind(root._inputs, root._behind);
        // Enrichit chaque input du head amont résolu (channel ou branche par défaut) : sert
        // au lien changelog de la vue. Hors modèle golden (dépend de la résolution réseau).
        var heads = root._heads;
        list = list.map(function (it) {
            it.head = heads[it.name] || it.channel || "";
            return it;
        });
        root.inputs = list;
        root.behindCount = Model.behindCount(list);
        root.upToDateCount = Model.upToDateCount(list);
        root.barState = Model.barState(list, false);
        root.connectionStatus = "live";
        root.errorMessage = "";
        root.lastCheck = Date.now() / 1000;
        root._busy = false;
    }

    // Best-effort : conserve le dernier état connu (DESIGN inv. 7).
    function _fail(msg) {
        root.connectionStatus = "error";
        root.errorMessage = msg;
        root._busy = false;
    }

    function _parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    // ---- Génération système courante (lecture seule, best-effort) ----

    property Process genRevProc: Process {
        running: false
        command: ["readlink", "/nix/var/nix/profiles/system"]
        stdout: StdioCollector {
            onStreamFinished: root.generation = Model.parseGeneration(text.trim())
        }
    }
    property Process genTimeProc: Process {
        running: false
        command: ["stat", "-c", "%Y", "/nix/var/nix/profiles/system"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = parseInt(text.trim(), 10);
                if (!isNaN(t))
                    root.generationActivatedAt = t;
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: root.intervalMs
        running: root.configured
        repeat: true
        triggeredOnStart: true // premier check immédiat
        onTriggered: root.poll()
    }

    Component.onCompleted: reconfigure()
}
