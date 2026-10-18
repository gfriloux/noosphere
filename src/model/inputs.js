.pragma library

// Drift-model transforms. PURE functions: the same inputs (`nix flake metadata --json`
// output + GitHub compare responses) → the same domain model (see the golden tests).
// Input = already-parsed JSON; output = noosphere's model.

// `nix flake metadata --json` output → the flake's **direct inputs** (those declared at the
// root: `locks.nodes[root].inputs`), sorted by name so the rendering is deterministic. We do
// NOT descend into transitive nodes (see DESIGN.md: the input is the unit).
//
// Each input: { name, type, owner, repoName, lockRev, lockedAt, channel }.
// - github: owner/repoName/lockRev filled in; channel = original.ref (e.g. nixos-unstable)
//   or "" when the input follows the default branch, resolved later by the service.
// - other types (git, path, tarball…): displayed, never compared → owner/repoName/channel
//   empty, lockRev best-effort (locked.rev when present).
function parseMetadata(meta) {
    var locks = (meta && meta.locks) || {};
    var nodes = locks.nodes || {};
    var rootKey = locks.root || "root";
    var root = nodes[rootKey] || {};
    var direct = root.inputs || {};

    var out = [];
    var names = Object.keys(direct).sort();
    for (var i = 0; i < names.length; i++) {
        var name = names[i];
        var ref = direct[name];
        // A root-level `follows` is an array (a redirection with no lock of its own): skipped.
        if (typeof ref !== "string")
            continue;
        var node = nodes[ref];
        if (!node)
            continue;
        var locked = node.locked || {};
        var original = node.original || {};
        var type = locked.type || original.type || "";
        var isGithub = type === "github";
        out.push({
            "name": name,
            "type": type,
            "owner": isGithub ? (locked.owner || "") : "",
            "repoName": isGithub ? (locked.repo || "") : "",
            "lockRev": locked.rev || "",
            "lockedAt": (locked.lastModified !== undefined ? locked.lastModified : 0),
            "channel": isGithub ? (original.ref || "") : ""
        });
    }
    return out;
}

// GitHub compare response → the input's lag (`behind`). `ahead_by` = the number of commits
// by which the upstream branch (head) is ahead of the locked revision (base). null when the
// response carries no `ahead_by` (error, rate limit, non-comparable input).
function parseCompare(res) {
    if (res && typeof res.ahead_by === "number")
        return res.ahead_by;
    return null;
}

// Is the compare response `res` really about the locked revision `lockRev`?
// GitHub returns the comparison's base in `base_commit.sha`: that is the only way to attach
// a response to the input that asked for it. A late response (abandoned request, skipped
// step) or an error does not match → the driver discards it instead of attributing its lag
// to the neighbour. See DESIGN.md invariant 10.
function compareBelongsTo(res, lockRev) {
    if (!lockRev)
        return false;
    return !!(res && res.base_commit && res.base_commit.sha === lockRev);
}

// GitHub repo response → the default branch, resolving the head of inputs with no explicit `ref`.
function parseDefaultBranch(res) {
    return (res && res.default_branch) || "";
}

// The same attribution as `compareBelongsTo`, for the `GET /repos/<owner>/<repo>` response:
// `full_name` identifies the repository asked about. A response naming a different repository
// would resolve one input's head to another's default branch.
function repoBelongsTo(res, owner, repoName) {
    if (!owner || !repoName)
        return false;
    return !!(res && res.full_name === owner + "/" + repoName);
}

// A GitHub call's HTTP status → a named cause, or `null` when the call went fine.
// Returns { code, fatal, status } — a code, never a sentence: the view turns it into words,
// which is what lets the wording be translated while this layer stays pure. `status` travels
// with it so the view can render "(503)".
//
// `fatal` separates a cause that holds for **every** later request (token refused, rate
// limit: hammering them would only make it worse) from one specific to a single input
// (repository not found, server incident), where the poll carries on and that input simply
// stays indeterminately behind.
//
// `timedOut`: we abandoned the request ourselves. Without that flag a network failure and a
// timeout would be indistinguishable — both yield `status === 0`.
function githubError(status, body, timedOut) {
    if (status >= 200 && status < 300)
        return null;

    if (status === 0) {
        return {
            "code": timedOut ? "timeout" : "offline",
            "fatal": false,
            "status": 0
        };
    }
    if (status === 401)
        return {
            "code": "token-refused",
            "fatal": true,
            "status": status
        };
    if (status === 429)
        return {
            "code": "rate-limited",
            "fatal": true,
            "status": status
        };
    if (status === 403) {
        // GitHub returns 403 both for a rate limit and for forbidden access; only the body
        // tells them apart. Unreadable → fall back to the generic case.
        var msg = "";
        try {
            msg = (JSON.parse(body) || {}).message || "";
        } catch (e) {
            msg = "";
        }
        var limited = msg.toLowerCase().indexOf("rate limit") >= 0;
        return {
            "code": limited ? "rate-limited" : "forbidden",
            "fatal": true,
            "status": status
        };
    }
    if (status === 404)
        return {
            "code": "not-found",
            "fatal": false,
            "status": status
        };
    if (status >= 500)
        return {
            "code": "unavailable",
            "fatal": false,
            "status": status
        };
    return {
        "code": "unexpected",
        "fatal": false,
        "status": status
    };
}

// The head to compare an input against: its `channel` (the tracked ref), otherwise the
// repository's default branch, which the service resolves.
function upstreamRef(input, fallbackBranch) {
    return input.channel || fallbackBranch || "";
}

// Annotates each input with its lag from a { name: behind } map. A name absent from the map
// → behind null (indeterminate: non-github, unresolved, or an error). Order is preserved.
function mergeBehind(inputs, behindByName) {
    behindByName = behindByName || {};
    return inputs.map(function (it) {
        var b = behindByName[it.name];
        return {
            "name": it.name,
            "type": it.type,
            "owner": it.owner,
            "repoName": it.repoName,
            "lockRev": it.lockRev,
            "lockedAt": it.lockedAt,
            "channel": it.channel,
            "behind": (typeof b === "number" ? b : null)
        };
    });
}

// How many inputs are actually behind (behind > 0). null and 0 do not count.
function behindCount(inputs) {
    var n = 0;
    for (var i = 0; i < inputs.length; i++)
        if (typeof inputs[i].behind === "number" && inputs[i].behind > 0)
            n += 1;
    return n;
}

// How many inputs are up to date (behind === 0). Feeds the INPUTS card's subtitle.
function upToDateCount(inputs) {
    var n = 0;
    for (var i = 0; i < inputs.length; i++)
        if (inputs[i].behind === 0)
            n += 1;
    return n;
}

// The badge's state. rebuilding (a future cap) wins; otherwise drift when any input is
// behind, otherwise uptodate. In v1 rebuilding is never passed as true (read-only).
function barState(inputs, rebuilding) {
    if (rebuilding)
        return "rebuilding";
    return behindCount(inputs) > 0 ? "drift" : "uptodate";
}

// The system profile symlink's target (/nix/var/nix/profiles/system) → generation number.
// "…/system-142-link" → 142; 0 when unrecognised. Read-only (readlink), best-effort.
function parseGeneration(linkTarget) {
    var m = /system-(\d+)-link\/?$/.exec(linkTarget || "");
    return m ? parseInt(m[1], 10) : 0;
}
