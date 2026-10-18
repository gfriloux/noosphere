.pragma library
.import "../query/queries.js" as Queries
.import "inputs.js" as Model

// The sequential poll driver, as a pure state machine.
//
// It used to live inside src/view/Noosphere.qml, where nothing could test it: a QML file
// importing Quickshell.Io cannot be loaded by qmltestrunner (Quickshell's types live in the
// quickshell binary, not in a plugin library), and under the quickshell binary QtTest's
// assertions do not fail anything. So every invariant this driver asserts was verified by
// hand only — in the one layer where this project's live bugs appeared.
//
// Here there is no QML, no network, no clock and no I/O. The driver decides and returns an
// **effect** for its caller to perform:
//
//   { kind: "get",    url, token }   issue a GET, restart the step watchdog, then call
//                                    onHttpDone with this same token
//   { kind: "commit", verified }     publish model(st); `verified: false` means the poll
//                                    completed without confirming anything (see
//                                    nothingVerified)
//   { kind: "fail",   cause, status } keep the last known state, show the cause
//   { kind: "noop" }                 nothing happened; the caller does nothing
//
// DESIGN invariant 10 — "a response belongs to the input that asked for it", and an
// abandoned request never advances a step — is **structural here**: every `get` carries a
// token, and onHttpDone ignores any response whose token is not the one currently awaited.
// That is what makes the invariant unit-testable instead of a comment.

function create(cfg) {
    return {
        apiBase: (cfg && cfg.apiBase) || "",
        inputs: [],      // parseMetadata output, before any lag
        behind: ({}),    // name → behind, only for responses that were attributed
        heads: ({}),     // name → resolved upstream ref (feeds the view's changelog link)
        queue: [],       // the comparable inputs, in order
        cursor: 0,
        phase: "",       // "repo" | "compare" — what the awaited response is
        awaiting: false, // is a request in flight from the driver's point of view
        seq: 0,
        token: -1,       // token of the awaited request; never matched once invalidated
        // The last NON-fatal GitHub error of this poll. A fatal one ends the poll and
        // travels in the `fail` effect; a non-fatal one only makes its own input
        // indeterminate, and used to be forgotten. But when every input fails non-fatally
        // the poll still commits with nothing verified, and that is the commonest failure
        // there is — an offline laptop. Keeping the cause here is what lets the status row
        // say "network unreachable" instead of only "no input could be verified".
        lastCause: "",
        lastStatus: 0
    };
}

// ---- Public: the predicate #7 turns on -------------------------------------------------

// Did this poll confirm nothing? True only when there was something to confirm and none of
// it resolved either way. A flake with no comparable input (DESIGN invariant 4: non-github
// types are displayed, never compared) has nothing to verify, which is not a failure.
function nothingVerified(st) {
    if (!st.queue.length)
        return false;
    for (var k in st.behind)
        if (st.behind.hasOwnProperty(k))
            return false;
    return true;
}

// What a commit should publish alongside the model. Pure, so the decision #7 turns on is
// under test instead of living in untested QML. It returns a **cause code**, never a
// sentence: the view turns the code into words, which is what lets the wording be
// translated.
//
// A poll that confirmed nothing is **not** a poll that found nothing: it reports the error
// status, which is what greys the bar badge (DESIGN's *Secondary states*), and leaves
// `lastCheck` alone. Refreshing `lastCheck` there would advertise a verification that never
// happened, and the badge and the timestamp would then say different things about the same
// state — which invariant 11 forbids.
function commitStatus(st) {
    if (nothingVerified(st))
        return {
            connectionStatus: "error",
            cause: "nothing-verified",
            // Why nothing could be verified, when the poll saw a reason. "" when every
            // input simply went unattributed without an HTTP error of its own.
            detail: st.lastCause,
            status: st.lastStatus,
            touchLastCheck: false
        };
    return {
        connectionStatus: "live",
        cause: "",
        detail: "",
        status: 0,
        touchLastCheck: true
    };
}

// ---- Public: the published model --------------------------------------------------------

function model(st) {
    var list = Model.mergeBehind(st.inputs, st.behind);
    var heads = st.heads;
    list = list.map(function (it) {
        // Outside the golden model: depends on what the network resolved.
        it.head = heads[it.name] || it.channel || "";
        return it;
    });
    return {
        inputs: list,
        behindCount: Model.behindCount(list),
        upToDateCount: Model.upToDateCount(list),
        barState: Model.barState(list, false)
    };
}

// ---- Public: entry points ---------------------------------------------------------------

function begin(st, metaJsonText) {
    var meta = _parse(metaJsonText);
    if (meta === null)
        return _fail(st, "metadata-unreadable", 0);

    st.inputs = Model.parseMetadata(meta);
    st.behind = {};
    st.heads = {};
    // A fresh poll forgets the previous one's cause, or a poll that fails to verify
    // anything for a new reason would publish the old one.
    st.lastCause = "";
    st.lastStatus = 0;
    st.queue = st.inputs.filter(function (it) {
        return it.type === "github" && it.owner && it.repoName;
    });
    st.cursor = 0;
    return _next(st);
}

// `nix` itself failed. `exitCode` travels so the view can name it.
function onMetaFailed(st, exitCode) {
    return _fail(st, "flake-unreadable", exitCode);
}

function onHttpDone(st, token, status, text, timedOut) {
    // The whole attribution invariant, in one line: a response we are no longer waiting for
    // cannot advance anything.
    if (!st.awaiting || token !== st.token)
        return {
            kind: "noop"
        };
    st.awaiting = false;

    var err = Model.githubError(status, text, timedOut);
    if (err && err.fatal)
        return _fail(st, err.code, err.status); // holds for every later request too
    if (err) {
        // Non-fatal: this input stays indeterminate and the poll moves on. Remember why,
        // so a poll where EVERY input failed this way can still name the cause at commit.
        st.lastCause = err.code;
        st.lastStatus = err.status;
    }

    var res = err ? null : _parse(text);
    var it = st.queue[st.cursor];
    if (!it)
        return _fail(st, "out-of-queue", 0);

    if (st.phase === "repo") {
        // The response must name the repository we asked about, or it came from elsewhere.
        var head = Model.repoBelongsTo(res, it.owner, it.repoName) ? Model.parseDefaultBranch(res) : "";
        if (head)
            return _compare(st, it, head);
        return _advance(st); // unresolved upstream → this input stays indeterminate
    }

    // The response must be about THIS input's locked revision.
    if (Model.compareBelongsTo(res, it.lockRev)) {
        var b = Model.parseCompare(res);
        if (typeof b === "number")
            st.behind[it.name] = b;
    }
    return _advance(st);
}

// A step that never answered. Give up on it and move on, so a poll always hands control
// back: without this a lost step would strand the driver and a manual re-check would stay
// silent for good. The input it gave up on simply stays indeterminate.
function onWatchdog(st) {
    if (!st.awaiting)
        return _fail(st, "watchdog-timeout", 0);
    _invalidate(st);
    return _advance(st);
}

// ---- Internals --------------------------------------------------------------------------

function _parse(text) {
    try {
        return JSON.parse(text);
    } catch (e) {
        return null;
    }
}

// Bump the awaited token so any response still in flight becomes a noop.
function _invalidate(st) {
    st.awaiting = false;
    st.token = ++st.seq;
}

function _get(st, phase, url) {
    st.phase = phase;
    st.awaiting = true;
    st.token = ++st.seq;
    return {
        kind: "get",
        url: url,
        token: st.token
    };
}

function _next(st) {
    if (st.cursor >= st.queue.length)
        return {
            kind: "commit",
            verified: !nothingVerified(st)
        };
    var it = st.queue[st.cursor];
    if (it.channel)
        return _compare(st, it, it.channel);
    // No tracked ref → resolve the repository's default branch first.
    return _get(st, "repo", Queries.repoApiUrl(st.apiBase, it.owner, it.repoName));
}

function _compare(st, it, head) {
    st.heads[it.name] = head;
    return _get(st, "compare", Queries.compareApiUrl(st.apiBase, it.owner, it.repoName, it.lockRev, head));
}

function _advance(st) {
    st.cursor += 1;
    return _next(st);
}

function _fail(st, cause, status) {
    _invalidate(st);
    return {
        kind: "fail",
        cause: cause,
        status: status || 0
    };
}
