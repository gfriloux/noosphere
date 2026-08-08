.pragma library

// Transforms du modèle de dérive. Fonctions PURES : mêmes entrées (sortie de
// `nix flake metadata --json` + réponses compare GitHub) → même modèle de domaine
// (cf. golden tests). Entrée = JSON déjà parsé ; sortie = modèle noosphere.

// Sortie de `nix flake metadata --json` → liste des **inputs directs** du flake (ceux
// déclarés à la racine : `locks.nodes[root].inputs`), triés par nom pour un rendu
// déterministe. On ne descend PAS dans le transitif (cf. DESIGN.md : l'input est l'unité).
//
// Chaque input : { name, type, owner, repoName, lockRev, lockedAt, channel }.
// - github : owner/repoName/lockRev renseignés ; channel = original.ref (ex. nixos-unstable)
//   ou "" si l'input suit la branche par défaut (résolue plus tard par le service).
// - autres types (git, path, tarball…) : affichés, jamais comparés → owner/repoName/channel
//   vides, lockRev best-effort (locked.rev s'il existe).
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
        // `follows` au niveau racine → valeur en tableau (redirection, pas de lock propre) : ignoré.
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

// Réponse compare GitHub → retard (`behind`) de l'input. `ahead_by` = nb de commits dont
// la branche amont (head) est en avance sur la révision verrouillée (base). null si la
// réponse ne porte pas d'`ahead_by` (erreur, rate-limit, input non comparable).
function parseCompare(res) {
    if (res && typeof res.ahead_by === "number")
        return res.ahead_by;
    return null;
}

// La réponse compare `res` porte-t-elle bien sur la révision verrouillée `lockRev` ?
// GitHub renvoie la base de la comparaison dans `base_commit.sha` : c'est le seul moyen de
// rattacher une réponse à l'input qui l'a demandée. Une réponse tardive (requête abandonnée,
// étape sautée) ou d'erreur ne matche pas → le service la jette au lieu d'attribuer son
// retard au voisin (cf. .claude/plans/v0.2.1/plan.md).
function compareBelongsTo(res, lockRev) {
    if (!lockRev)
        return false;
    return !!(res && res.base_commit && res.base_commit.sha === lockRev);
}

// Réponse repo GitHub → branche par défaut (résout le head des inputs sans `ref` explicite).
function parseDefaultBranch(res) {
    return (res && res.default_branch) || "";
}

// Même rattachement que `compareBelongsTo`, pour la réponse `GET /repos/<owner>/<repo>` :
// `full_name` identifie le dépôt interrogé. Une réponse qui ne désigne pas le dépôt attendu
// résoudrait le head d'un input sur la branche par défaut d'un autre.
function repoBelongsTo(res, owner, repoName) {
    if (!owner || !repoName)
        return false;
    return !!(res && res.full_name === owner + "/" + repoName);
}

// Statut HTTP d'un appel GitHub → cause nommée, ou `null` si l'appel s'est bien passé.
// Rendu : { message, fatal }.
//
// `fatal` distingue une cause qui vaut pour **toutes** les requêtes suivantes (jeton
// refusé, limite de débit : les marteler ne ferait qu'aggraver) d'une cause propre à un
// seul input (dépôt introuvable, incident serveur), auquel cas le poll continue et cet
// input reste simplement en retard indéterminé.
//
// `timedOut` : nous avons abandonné la requête nous-mêmes. Sans ce drapeau la panne réseau
// et le délai dépassé seraient indiscernables — tous deux rendent `status === 0`.
function githubError(status, body, timedOut) {
    if (status >= 200 && status < 300)
        return null;

    if (status === 0) {
        return {
            "message": timedOut ? "délai dépassé" : "réseau injoignable",
            "fatal": false
        };
    }
    if (status === 401)
        return {
            "message": "token GitHub refusé",
            "fatal": true
        };
    if (status === 429)
        return {
            "message": "limite d'API GitHub atteinte",
            "fatal": true
        };
    if (status === 403) {
        // GitHub rend 403 aussi bien pour une limite de débit que pour un accès interdit ;
        // seul le corps les sépare. Illisible → on s'en tient au cas générique.
        var msg = "";
        try {
            msg = (JSON.parse(body) || {}).message || "";
        } catch (e) {
            msg = "";
        }
        var limite = msg.toLowerCase().indexOf("rate limit") >= 0;
        return {
            "message": limite ? "limite d'API GitHub atteinte" : "accès refusé par GitHub",
            "fatal": true
        };
    }
    if (status === 404)
        return {
            "message": "dépôt introuvable",
            "fatal": false
        };
    if (status >= 500)
        return {
            "message": "GitHub indisponible (" + status + ")",
            "fatal": false
        };
    return {
        "message": "réponse inattendue de GitHub (" + status + ")",
        "fatal": false
    };
}

// Head à comparer pour un input : sa `channel` (ref suivie) sinon la branche par défaut
// du repo (fallback résolu par le service).
function upstreamRef(input, fallbackBranch) {
    return input.channel || fallbackBranch || "";
}

// Annote chaque input de son retard depuis une map { name: behind }. Un name absent de la
// map → behind null (indéterminé : non-github, non résolu, ou erreur). Conserve l'ordre.
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

// Nombre d'inputs réellement en retard (behind > 0). Les behind null/0 ne comptent pas.
function behindCount(inputs) {
    var n = 0;
    for (var i = 0; i < inputs.length; i++)
        if (typeof inputs[i].behind === "number" && inputs[i].behind > 0)
            n += 1;
    return n;
}

// Nombre d'inputs à jour (behind === 0). Sert au sous-titre « M à jour ».
function upToDateCount(inputs) {
    var n = 0;
    for (var i = 0; i < inputs.length; i++)
        if (inputs[i].behind === 0)
            n += 1;
    return n;
}

// État du badge. rebuilding (cap futur) l'emporte ; sinon drift si un input dérive, sinon
// uptodate. En v1, rebuilding n'est jamais passé à true (lecture seule).
function barState(inputs, rebuilding) {
    if (rebuilding)
        return "rebuilding";
    return behindCount(inputs) > 0 ? "drift" : "uptodate";
}

// Cible du symlink de profil système (/nix/var/nix/profiles/system) → numéro de génération.
// "…/system-142-link" → 142 ; 0 si non reconnu. Lecture seule (readlink), best-effort.
function parseGeneration(linkTarget) {
    var m = /system-(\d+)-link\/?$/.exec(linkTarget || "");
    return m ? parseInt(m[1], 10) : 0;
}
