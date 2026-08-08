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
