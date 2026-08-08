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
// Les appels GitHub partent du processus lui-même (XMLHttpRequest), jamais d'un `curl`
// externe : le token, passé en header `Authorization: Bearer`, ne traverse ainsi aucun argv.
// Il n'entre jamais dans les couches query/model (cf. DESIGN.md).
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
    //
    // Contrat : **une étape = une requête = une avance**. L'input est capturé dans `_current`
    // au moment où la requête part ; les handlers ne relisent jamais `_queue[_cursor]`, sans
    // quoi une réponse arrivant après une avance serait attribuée au voisin (qui afficherait
    // alors un retard sans head : invisible pour l'aperçu de closure et le lien changelog).
    // `_await` dit ce qu'on attend : tout ce qui ne correspond pas est ignoré, ce qui empêche
    // une étape d'avancer deux fois — cas restant depuis le passage en XHR : le watchdog a
    // déclaré l'étape perdue et avancé, puis la réponse arrive quand même.
    property var _inputs: [] // inputs bruts (parseMetadata), avant retard
    property var _behind: ({}) // accumulateur name → behind
    property var _heads: ({}) // accumulateur name → head amont résolu (pour le lien changelog)
    property var _queue: [] // inputs github à comparer
    property int _cursor: 0
    property bool _busy: false
    property var _current: null // input de l'étape en cours (capturé à l'émission)
    property string _await: "" // ce qu'on attend : "" | "repo" | "compare"
    property var _pending: null // requête HTTP en vol (une seule à la fois) : { xhr, timedOut, settled }

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
        stepWatchdog.restart();
        metaProc.command = ["nix"].concat(Queries.flakeMetadata(root.flakePath));
        metaProc.running = true;
        // Génération courante : best-effort, indépendant du pipeline de dérive.
        genRevProc.running = true;
        genTimeProc.running = true;
    }

    // Chien de garde d'étape. Une requête HTTP a son propre délai (`httpTimeout`), mais rien
    // ne garantit qu'un signal nous parvienne (`nix` qui s'éternise, flux jamais clos, rappel
    // perdu). Sans ce filet, un poll n'atteindrait ni `_commit()` ni `_fail()` : `_busy` resterait vrai et
    // « check maintenant » serait muet **définitivement**. Une étape perdue laisse simplement
    // son input en retard indéterminé, on passe au suivant.
    property Timer stepWatchdog: Timer {
        interval: 60000
        repeat: false
        onTriggered: {
            if (!root._busy)
                return;
            if (root._await.length > 0) {
                root._await = "";
                root._abortPending(); // sinon sa réponse tardive ferait avancer l'étape suivante
                root._advance();
            } else {
                root._fail("check interrompu (délai dépassé)");
            }
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
        var xhr = new XMLHttpRequest();
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
        if (meta === null) {
            // `nix` a rendu 0 mais du non-JSON : sans issue explicite le poll resterait en vol.
            root._fail("métadonnées du flake illisibles");
            return;
        }
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
        root._await = "";
        root._current = null;
        if (root._cursor >= root._queue.length) {
            root._commit();
            return;
        }
        var it = root._queue[root._cursor];
        root._current = it;
        if (it.channel) {
            root._compare(it, it.channel);
        } else {
            // Pas de ref suivie → résoudre la branche par défaut du repo d'abord.
            root._await = "repo";
            stepWatchdog.restart();
            root._ghGet(Queries.repoApiUrl(root.apiBase, it.owner, it.repoName), function (status, text, timedOut) {
                if (root._await !== "repo")
                    return; // réponse d'une étape déjà close : elle ne nous concerne plus
                var cur = root._current;
                root._await = "";
                var err = Model.githubError(status, text, timedOut);
                if (err && err.fatal) {
                    root._fail(err.message); // vaut pour toutes les requêtes suivantes
                    return;
                }
                var res = err ? null : root._parse(text);
                // La réponse doit désigner le dépôt interrogé, sinon elle vient d'ailleurs.
                var head = Model.repoBelongsTo(res, cur.owner, cur.repoName) ? Model.parseDefaultBranch(res) : "";
                if (head)
                    root._compare(cur, head);
                else
                    root._advance(); // non résolu → behind reste indéterminé
            });
        }
    }

    function _compare(it, head) {
        root._heads[it.name] = head; // mémorisé pour le lien changelog de la vue
        root._await = "compare";
        stepWatchdog.restart();
        root._ghGet(Queries.compareApiUrl(root.apiBase, it.owner, it.repoName, it.lockRev, head), function (status, text, timedOut) {
            if (root._await !== "compare")
                return;
            var cur = root._current;
            root._await = "";
            var err = Model.githubError(status, text, timedOut);
            if (err && err.fatal) {
                root._fail(err.message);
                return;
            }
            var res = err ? null : root._parse(text);
            // La réponse doit porter sur la révision verrouillée de CET input.
            if (Model.compareBelongsTo(res, cur.lockRev)) {
                var b = Model.parseCompare(res);
                if (typeof b === "number")
                    root._behind[cur.name] = b;
            }
            root._advance();
        });
    }

    function _advance() {
        root._cursor += 1;
        root._next();
    }

    // ---- Aboutissement ----

    function _commit() {
        stepWatchdog.stop();
        root._await = "";
        root._current = null;
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

    // Abandonne la requête en vol, s'il y en a une : sans cela, une réponse tardive resterait
    // à courir pendant le poll suivant (le garde `_await` l'ignorerait, mais autant ne pas la
    // laisser vivre) et `httpTimeout` viendrait interrompre la requête d'après.
    function _abortPending() {
        var p = root._pending;
        root._pending = null;
        httpTimeout.stop();
        if (p && !p.settled) {
            p.settled = true;
            p.xhr.abort();
        }
    }

    // Best-effort : conserve le dernier état connu (DESIGN inv. 7). Clôt l'étape en cours pour
    // qu'une réponse tardive ne vienne pas s'appliquer au poll suivant.
    function _fail(msg) {
        stepWatchdog.stop();
        root._abortPending();
        root._await = "";
        root._current = null;
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
