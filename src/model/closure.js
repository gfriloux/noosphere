.pragma library

// Closure-diff transforms. PURE functions: the same frozen `nvd diff` output → the same
// model (see the golden tests). Input = raw `nvd diff` text, output = noosphere's model.
//
// `nvd diff` format (see DESIGN.md / the fixtures):
//   <<< <current>
//   >>> <target>
//   Version changes:
//   [C*]  #1  curl  8.20.0 -> 8.20.1
//   Added packages:
//   [A.]  #1  noosphere-plugin  <none>
//   Removed packages:
//   [R.]  #1  oldpkg  1.0
//   Closure size: 2900 -> 2904 (17 paths added, 13 paths removed, delta +4, disk usage +142.7KiB).

// A change's severity (local heuristic, see DESIGN.md): kernel / firmware / graphics driver
// / microcode → `reboot` (activating it will require a restart); otherwise `neutral`.
// CVE badges are deferred — no reliable local source of security advisories.
function closureSeverity(name) {
    var n = (name || "").toLowerCase();
    if (n === "linux" || n.indexOf("linux-") === 0 || /(^|-)firmware$/.test(n) || n.indexOf("mesa") === 0 || n.indexOf("nvidia") === 0 || n.indexOf("microcode") !== -1)
        return "reboot";
    return "neutral";
}

// The card's maximum severity: reboot if any change demands it, otherwise neutral.
function cardSeverity(entries) {
    for (var i = 0; i < entries.length; i++)
        if (entries[i].severity === "reboot")
            return "reboot";
    return "neutral";
}

// One entry line: `[<flags>]  #<n>  <name>  <value>`. The name is a single token (package
// names carry no space); the value is the rest. `kind` comes from the current section.
function _entry(line, kind) {
    var m = /^\[[^\]]*\]\s+#\d+\s+(\S+)\s+(.*)$/.exec(line);
    if (!m)
        return null;
    var name = m[1];
    var value = m[2].trim();
    var from = "", to = "";
    if (kind === "changed") {
        var i = value.indexOf(" -> ");
        if (i >= 0) {
            from = value.slice(0, i).trim();
            to = value.slice(i + 4).trim();
        } else {
            to = value;
        }
    } else if (kind === "added") {
        to = value;
    } else {
        // removed
        from = value;
    }
    return {
        "name": name,
        "from": from,
        "to": to,
        "kind": kind,
        "severity": closureSeverity(name)
    };
}

// The `Closure size: A -> B (… N paths added, M paths removed, …, disk usage ±X).` line.
function _closureLine(line, out) {
    var pa = /(\d+)\s+paths added/.exec(line);
    var pr = /(\d+)\s+paths removed/.exec(line);
    var du = /disk usage\s+([^,)]+)/.exec(line);
    if (pa)
        out.pathsAdded = parseInt(pa[1], 10);
    if (pr)
        out.pathsRemoved = parseInt(pr[1], 10);
    if (du)
        out.sizeDelta = du[1].trim();
}

// `nvd diff` text → the closure model.
function parseNvdDiff(text) {
    var out = {
        "updated": 0,
        "added": 0,
        "removed": 0,
        "pathsAdded": 0,
        "pathsRemoved": 0,
        "sizeDelta": "",
        "entries": []
    };
    var lines = (text || "").split("\n");
    var section = ""; // "changed" | "added" | "removed"
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (/^Version changes:/.test(line)) {
            section = "changed";
            continue;
        }
        if (/^Added packages:/.test(line)) {
            section = "added";
            continue;
        }
        if (/^Removed packages:/.test(line)) {
            section = "removed";
            continue;
        }
        if (/^Closure size:/.test(line)) {
            _closureLine(line, out);
            section = "";
            continue;
        }
        if (section && line.charAt(0) === "[") {
            var e = _entry(line, section);
            if (e)
                out.entries.push(e);
        }
    }
    // Counters derived from the entries, by kind.
    for (var j = 0; j < out.entries.length; j++) {
        var k = out.entries[j].kind;
        if (k === "changed")
            out.updated += 1;
        else if (k === "added")
            out.added += 1;
        else if (k === "removed")
            out.removed += 1;
    }
    return out;
}
