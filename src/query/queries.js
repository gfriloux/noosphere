.pragma library

// Construction des commandes (argv) et des URLs d'API. Fonctions PURES, testables : elles
// ne construisent que la commande / l'URL, sans réseau ni authentification.
//
// L'auth GitHub (optionnelle) vit dans le header HTTP `Authorization: Bearer <token>`,
// injecté par le service (src/view/Noosphere.qml) : le token n'apparaît JAMAIS ici.
// Corollaire : aucun secret dans ces builders, donc les fixtures/goldens dérivés sont
// committables sans risque (cf. DESIGN.md).

// nix flake metadata --json [<path>] → métadonnées du flake (inputs + locks) en JSON.
// On retourne un tableau d'arguments — jamais une ligne shell : le chemin (qui peut
// contenir des espaces) reste UN seul élément, pas de découpage ni d'injection.
// `path` absent → nix résout le flake du répertoire courant.
function flakeMetadata(path) {
    var args = ["flake", "metadata", "--json"];
    if (path)
        args.push(path);
    return args;
}

// Base par défaut de l'API GitHub. Surchargeable (`apiBase`) pour pointer un mock local
// en dev (`just mock`) sans toucher au réseau — cf. scripts/github-mock.py.
var GITHUB_API = "https://api.github.com";

// URL de l'API compare GitHub : GET <apiBase>/repos/<owner>/<repo>/compare/<base>...<head>.
// La réponse porte `ahead_by` = nombre de commits dont `head` (branche amont) est en
// avance sur `base` (révision verrouillée du lock) = le **retard** de l'input.
function compareApiUrl(apiBase, owner, repo, base, head) {
    return (apiBase || GITHUB_API) + "/repos/" + owner + "/" + repo + "/compare/" + base + "..." + head;
}

// URL de l'API repo GitHub : GET <apiBase>/repos/<owner>/<repo>. Sert à résoudre la branche
// par défaut (`default_branch`) d'un input qui ne suit pas de `ref` explicite (cf. model).
function repoApiUrl(apiBase, owner, repo) {
    return (apiBase || GITHUB_API) + "/repos/" + owner + "/" + repo;
}

// --- Diff de closure (v0.2.0, build à la demande — cf. DESIGN.md) ---

// Référence flake d'un input github verrouillé sur son amont : github:<owner>/<repo>/<ref>.
// `ref` = branche suivie (channel ou branche par défaut). Résout au dernier commit de la
// branche à l'évaluation → cible d'un --override-input pour prévisualiser une mise à jour.
function githubFlakeRef(owner, repo, ref) {
    return "github:" + owner + "/" + repo + "/" + ref;
}

// nix build du toplevel de la config NixOS <host> du flake <path>, SANS activation.
// `--no-link` : pas de symlink `result` ; `--print-out-paths` : imprime le store path du
// toplevel (= cible du nvd diff). `overrides` (optionnel) : liste { name, ref } d'inputs à
// pointer sur leur amont via `--override-input` — évalue « comme si mis à jour » **sans
// écrire flake.lock ni activer** (cf. DESIGN.md : aperçu de mise à jour, lecture seule).
// Argv (path, host, refs restent des éléments distincts : pas de découpage shell).
function buildToplevel(flakePath, host, overrides) {
    var args = ["build", flakePath + "#nixosConfigurations." + host + ".config.system.build.toplevel", "--no-link", "--print-out-paths"];
    var list = overrides || [];
    for (var i = 0; i < list.length; i++)
        args.push("--override-input", list[i].name, list[i].ref);
    return args;
}

// nvd diff <current> <target> → aperçu texte des changements de closure. `current` défaut
// `/run/current-system` (génération active). Argv pour la commande `nvd`.
function nvdDiff(current, target) {
    return ["diff", current || "/run/current-system", target];
}

// hostname → résout l'hôte courant quand il n'est pas configuré (clé de nixosConfigurations).
function hostnameArgv() {
    return ["hostname"];
}
