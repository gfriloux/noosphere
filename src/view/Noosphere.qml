// Service noosphere : lit le flake local (`nix flake metadata --json`), interroge l'amont
// GitHub (compare) pour chaque input, assemble le modèle de dérive et poll périodiquement.
// Lecture seule : aucun `nix flake update`, aucun `nixos-rebuild`.
//
// Depuis v0.4.0 ce fichier ne décide plus rien : la machine à états du poll vit dans
// `src/model/poll.js`, pure et testée par `tests/tst_poll.qml`. Ce qui reste ici est l'I/O
// que le driver ne peut pas porter — les `Process`, les `XMLHttpRequest`, les `Timer` — plus
// la publication du modèle. Le driver rend un **effet** (`get` / `commit` / `fail` / `noop`)
// et `_perform()` l'exécute.
//
// Pourquoi ce découpage : un QML qui importe `Quickshell.Io` ne peut pas être chargé par
// `qmltestrunner` (les types de Quickshell vivent dans le binaire, pas dans une bibliothèque
// de plugin), et sous le binaire `quickshell` les assertions de QtTest n'échouent jamais.
// Tant que le driver vivait ici, aucun test ne pouvait le couvrir.
//
// Les appels GitHub partent du processus lui-même (XMLHttpRequest), jamais d'un `curl`
// externe : le token, passé en header `Authorization: Bearer`, ne traverse ainsi aucun argv.
// Il n'entre jamais dans les couches query/model (cf. DESIGN.md).
import QtQuick
import Quickshell.Io
import "../query/queries.js" as Queries
import "../model/inputs.js" as Model
import "../model/poll.js" as Poll

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

    // --- État ---
    property var _st: null // état du driver (src/model/poll.js)
    property bool _busy: false
    property var _pending: null // requête HTTP en vol (une seule à la fois) : { xhr, timedOut, settled }

    // Fabrique du transport. Seul point de substitution restant dans ce fichier : la
    // production rend un vrai `XMLHttpRequest`, un test peut en rendre un faux.
    property var xhrFactory: function () {
        return new XMLHttpRequest();
    }

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
        root._st = Poll.create({
            "apiBase": root.apiBase
        });
        stepWatchdog.restart();
        metaProc.command = ["nix"].concat(Queries.flakeMetadata(root.flakePath));
        metaProc.running = true;
        // Génération courante : best-effort, indépendant du pipeline de dérive.
        genRevProc.running = true;
        genTimeProc.running = true;
    }

    // Exécute un effet rendu par le driver. C'est le seul endroit où une décision du driver
    // devient une action.
    function _perform(eff) {
        if (!eff)
            return;
        if (eff.kind === "noop")
            return;
        if (eff.kind === "get") {
            stepWatchdog.restart();
            var tok = eff.token;
            root._ghGet(eff.url, function (status, text, timedOut) {
                root._perform(Poll.onHttpDone(root._st, tok, status, text, timedOut));
            });
            return;
        }
        if (eff.kind === "commit") {
            root._publish();
            return;
        }
        if (eff.kind === "fail") {
            root._failWith(eff.message);
            return;
        }
    }

    // Publie le modèle du poll. Le statut vient de `Poll.commitStatus()`, pas d'ici : un poll
    // qui n'a **rien pu vérifier** publie quand même la liste fraîchement lue (le `nix flake
    // metadata` a réussi, seule la moitié GitHub a échoué) mais sous statut d'erreur, et sans
    // toucher `lastCheck`. Le badge est alors gris — `stateColor` dérive de
    // `connectionStatus === "error"` — au lieu d'annoncer « à jour » sans l'avoir vérifié.
    function _publish() {
        stepWatchdog.stop();
        var m = Poll.model(root._st);
        root.inputs = m.inputs;
        root.behindCount = m.behindCount;
        root.upToDateCount = m.upToDateCount;
        root.barState = m.barState;
        var cs = Poll.commitStatus(root._st);
        root.connectionStatus = cs.connectionStatus;
        root.errorMessage = cs.errorMessage;
        if (cs.touchLastCheck)
            root.lastCheck = Date.now() / 1000;
        root._busy = false;
    }

    // Best-effort : conserve le dernier état connu (DESIGN inv. 7). Clôt l'étape en cours pour
    // qu'une réponse tardive ne vienne pas s'appliquer au poll suivant.
    function _failWith(msg) {
        stepWatchdog.stop();
        root._abortPending();
        root.connectionStatus = "error";
        root.errorMessage = msg;
        root._busy = false;
    }

    // Chien de garde d'étape. Une requête HTTP a son propre délai (`httpTimeout`), mais rien
    // ne garantit qu'un signal nous parvienne (`nix` qui s'éternise, flux jamais clos, rappel
    // perdu). Sans ce filet, un poll n'atteindrait ni `commit` ni `fail` : `_busy` resterait
    // vrai et « check maintenant » serait muet **définitivement**. Le driver décide quoi faire
    // d'une étape perdue ; ici on abandonne seulement la requête en vol.
    property Timer stepWatchdog: Timer {
        interval: 60000
        repeat: false
        onTriggered: {
            if (!root._busy)
                return;
            root._abortPending();
            root._perform(Poll.onWatchdog(root._st));
        }
    }

    // Délai maximal d'une requête HTTP, en remplacement du `--max-time` de `curl` : Qt
    // n'implémente ni `xhr.timeout` ni `ontimeout`, seul `abort()` est disponible. 20 s,
    // valeur inchangée — un compare sur un dépôt très en retard renvoie jusqu'à 250 commits,
    // 10 s était atteignable et nous faisait abandonner nos propres requêtes.
    // Un timer unique suffit : le driver est séquentiel, une seule requête est en vol.
    property Timer httpTimeout: Timer {
        interval: 20000
        repeat: false
        onTriggered: {
            var p = root._pending;
            if (!p || p.settled)
                return;
            p.timedOut = true;
            p.xhr.abort(); // → readyState DONE, status 0 → `settle()`
        }
    }

    // GET JSON sur l'API GitHub, émis depuis le processus. Le token, s'il existe, part en
    // header `Authorization: Bearer` : contrairement à un argv de `curl`, il ne traverse
    // jamais `/proc/<pid>/cmdline`, lisible par tout processus local.
    //
    // `onDone(status, text, timedOut)` est appelé une fois et une seule. `timedOut`
    // distingue notre propre abandon d'une panne réseau : les deux rendent `status === 0`.
    function _ghGet(url, onDone) {
        root._abortPending(); // invariant : une seule requête vivante à la fois
        var xhr = root.xhrFactory();
        var state = {
            xhr: xhr,
            timedOut: false,
            settled: false
        };
        root._pending = state;
        var settle = function (status, text) {
            if (state.settled)
                return;
            state.settled = true;
            httpTimeout.stop();
            if (root._pending === state)
                root._pending = null;
            onDone(status, text, state.timedOut);
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            // `status` est inaccessible sur certains échecs de transport : on retombe sur 0,
            // que les appelants traitent déjà comme « pas de donnée ».
            var status = 0;
            var text = "";
            try {
                status = xhr.status;
                text = xhr.responseText || "";
            } catch (e) {
                status = 0;
            }
            settle(status, text);
        };
        xhr.open("GET", url);
        // Les headers se posent après `open()`.
        xhr.setRequestHeader("Accept", "application/vnd.github+json");
        xhr.setRequestHeader("X-GitHub-Api-Version", "2022-11-28");
        xhr.setRequestHeader("User-Agent", "noosphere");
        if (root.githubToken.length > 0)
            xhr.setRequestHeader("Authorization", "Bearer " + root.githubToken);
        httpTimeout.restart();
        xhr.send();
    }

    // Abandonne la requête en vol, s'il y en a une. Elle est marquée close **avant** `abort()`
    // pour que son rappel ne parte pas. Le driver garde par ailleurs son propre jeton, donc
    // une réponse tardive ne peut de toute façon pas faire avancer une étape.
    function _abortPending() {
        var p = root._pending;
        root._pending = null;
        httpTimeout.stop();
        if (p && !p.settled) {
            p.settled = true;
            p.xhr.abort();
        }
    }

    // 1er étage : nix flake metadata.
    property Process metaProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim())
                    root._perform(Poll.begin(root._st, text));
                // vide → échec, traité par onExited
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("noosphere nix:", text.trim())
        }
        // qmllint disable signal-handler-parameters
        // `exited(int, QProcess::ExitStatus)`: the second parameter is a C++ enum Quickshell
        // does not register for QML, so qmllint cannot resolve it. Remove once upstream
        // exposes ExitStatus in its qmltypes.
        onExited: code => {
            if (code !== 0 && root._busy)
                root._perform(Poll.onMetaFailed(root._st, "flake illisible (nix " + code + ")"));
        }
        // qmllint enable signal-handler-parameters
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
