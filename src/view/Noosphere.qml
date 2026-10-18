// noosphere's service: reads the local flake (`nix flake metadata --json`), queries GitHub
// upstream (compare) for each input, assembles the drift model and polls periodically.
// Read-only: no `nix flake update`, no `nixos-rebuild`.
//
// Since v0.4.0 this file decides nothing: the poll's state machine lives in
// `src/model/poll.js`, pure and tested by `tests/tst_poll.qml`. What remains here is the I/O
// the driver cannot carry — the `Process` objects, the `XMLHttpRequest` calls, the `Timer`s
// — plus publishing the model. The driver returns an **effect** (`get` / `commit` / `fail` /
// `noop`) and `_perform()` executes it.
//
// Why the split: a QML file importing `Quickshell.Io` cannot be loaded by `qmltestrunner`
// (Quickshell's types live in its binary, not in a plugin library), and under the
// `quickshell` binary QtTest's assertions never fail anything. While the driver lived here,
// no test could reach it.
//
// GitHub calls are issued by the process itself (XMLHttpRequest), never by an external
// `curl`: the token, passed in an `Authorization: Bearer` header, therefore crosses no argv.
// It never enters the query/model layers (see DESIGN.md).
import QtQuick
import Quickshell.Io
import "../query/queries.js" as Queries
import "../model/inputs.js" as Model
import "../model/poll.js" as Poll

QtObject {
    id: root

    // --- Config, injected by the widget from pluginData ---
    property string flakePath: "" // chemin du flake local (ex. /etc/nixos)
    property string githubToken: "" // optionnel : lève la limite 60 req/h
    property string apiBase: "" // vide = api.github.com ; surchargé pour le mock dev
    property int intervalMs: 3600000 // cadence par défaut : 1 h

    // --- Output: the domain model ---
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

    // Transport factory. The one substitution point left in this file: production returns
    // a real `XMLHttpRequest`, a test can return a fake.
    property var xhrFactory: function () {
        return new XMLHttpRequest();
    }

    // (Re)poll whenever a relevant setting changes.
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
        // Current generation: best-effort, independent of the drift pipeline.
        genRevProc.running = true;
        genTimeProc.running = true;
    }

    // Performs an effect returned by the driver. The only place a driver decision becomes
    // an action.
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

    // Publishes the poll's model. The status comes from `Poll.commitStatus()`, not from
    // here: a poll that could verify **nothing** still publishes the freshly read list
    // (`nix flake metadata` succeeded, only the GitHub half failed) but under an error
    // status, and without touching `lastCheck`. The badge then greys — `stateColor` derives
    // from `connectionStatus === "error"` — instead of announcing "up to date" unverified.
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

    // Best-effort: keeps the last known state (DESIGN invariant 7). Closes the step in
    // flight so a late response cannot apply itself to the next poll.
    function _failWith(msg) {
        stepWatchdog.stop();
        root._abortPending();
        root.connectionStatus = "error";
        root.errorMessage = msg;
        root._busy = false;
    }

    // Step watchdog. An HTTP request has its own timeout (`httpTimeout`), but nothing
    // guarantees a signal ever reaches us (a `nix` that drags on, a stream never closed, a
    // lost callback). Without this net a poll would reach neither `commit` nor `fail`:
    // `_busy` would stay true and the manual re-check would be mute **for good**. The driver
    // decides what to do with a lost step; here we only abandon the request in flight.
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

    // Maximum duration of an HTTP request, standing in for `curl`'s `--max-time`: Qt
    // implements neither `xhr.timeout` nor `ontimeout`, only `abort()`. 20 s, unchanged — a
    // compare on a badly lagging repository returns up to 250 commits, and 10 s was
    // reachable, which made us abandon our own requests.
    // One timer is enough: the driver is sequential, so only one request is ever in flight.
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

    // GET JSON against the GitHub API, issued from within the process. The token, when
    // there is one, travels in an `Authorization: Bearer` header: unlike a `curl` argv it
    // never crosses `/proc/<pid>/cmdline`, which any local process can read.
    //
    // `onDone(status, text, timedOut)` is called exactly once. `timedOut` separates our own
    // abandonment from a network failure: both yield `status === 0`.
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
            // `status` is unreachable on some transport failures: fall back to 0, which
            // callers already treat as "no data".
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
        // Headers are set after `open()`.
        xhr.setRequestHeader("Accept", "application/vnd.github+json");
        xhr.setRequestHeader("X-GitHub-Api-Version", "2022-11-28");
        xhr.setRequestHeader("User-Agent", "noosphere");
        if (root.githubToken.length > 0)
            xhr.setRequestHeader("Authorization", "Bearer " + root.githubToken);
        httpTimeout.restart();
        xhr.send();
    }

    // Abandons the request in flight, if there is one. It is marked settled **before**
    // `abort()` so its callback never fires. The driver also carries its own token, so a late
    // response cannot advance a step in any case.
    function _abortPending() {
        var p = root._pending;
        root._pending = null;
        httpTimeout.stop();
        if (p && !p.settled) {
            p.settled = true;
            p.xhr.abort();
        }
    }

    // Stage 1: nix flake metadata.
    property Process metaProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // The poll must still be running. Without this guard, a `nix` the watchdog
                // has already given up on (`_failWith`, so `_busy` false and the status
                // `error`) can answer afterwards and start a ghost poll: nothing bounds it
                // any more, and its `_publish()` would clear the error status and stamp
                // `lastCheck` — exactly what #7's fix exists to prevent.
                if (!root._busy)
                    return;
                if (text && text.trim())
                    root._perform(Poll.begin(root._st, text));
                // empty → a failure, handled by onExited
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("noosphere nix:", text.trim())
        }
        // qmllint disable signal-handler-parameters
        // `exited(int, QProcess::ExitStatus)`: the second parameter is a C++ enum Quickshell
        // does not register for QML, so qmllint cannot resolve it and warns on every such
        // handler. Remove once upstream exposes ExitStatus in its qmltypes.
        onExited: code => {
            if (code !== 0 && root._busy)
                root._perform(Poll.onMetaFailed(root._st, "flake illisible (nix " + code + ")"));
        }
        // qmllint enable signal-handler-parameters
    }

    // ---- Current system generation (read-only, best-effort) ----

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
