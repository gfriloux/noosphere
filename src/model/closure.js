.pragma library

// Transforms du diff de closure. Fonctions PURES : même sortie `nvd diff` figée → même
// modèle (cf. golden tests). Entrée = texte brut de `nvd diff`, sortie = modèle noosphere.
//
// Format `nvd diff` (cf. DESIGN.md / fixtures) :
//   <<< <current>
//   >>> <target>
//   Version changes:
//   [C*]  #1  curl  8.20.0 -> 8.20.1
//   Added packages:
//   [A.]  #1  noosphere-plugin  <none>
//   Removed packages:
//   [R.]  #1  oldpkg  1.0
//   Closure size: 2900 -> 2904 (17 paths added, 13 paths removed, delta +4, disk usage +142.7KiB).

// Sévérité d'un changement (heuristique locale, cf. DESIGN.md) : kernel / firmware / pilote
// graphique / microcode → `reboot` (l'activation exigera un redémarrage) ; sinon `neutral`.
// Les badges CVE sont reportés (aucune source d'avis de sécurité fiable en local).
function closureSeverity(name) {
    var n = (name || "").toLowerCase();
    if (n === "linux" || n.indexOf("linux-") === 0 || /(^|-)firmware$/.test(n) || n.indexOf("mesa") === 0 || n.indexOf("nvidia") === 0 || n.indexOf("microcode") !== -1)
        return "reboot";
    return "neutral";
}

// Sévérité maximale de la carte : reboot si un changement l'exige, sinon neutral.
function cardSeverity(entries) {
    for (var i = 0; i < entries.length; i++)
        if (entries[i].severity === "reboot")
            return "reboot";
    return "neutral";
}

// Une ligne d'entrée : `[<flags>]  #<n>  <nom>  <valeur>`. Le nom est un token unique (les
// paquets n'ont pas d'espace) ; la valeur est le reste. `kind` vient de la section courante.
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

// Ligne `Closure size: A -> B (… N paths added, M paths removed, …, disk usage ±X).`
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

// Texte `nvd diff` → modèle de closure.
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
    // Compteurs dérivés des entrées (par type).
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
