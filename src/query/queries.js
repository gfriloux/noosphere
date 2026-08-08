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

// URL de l'API compare GitHub : GET .../repos/<owner>/<repo>/compare/<base>...<head>.
// La réponse porte `ahead_by` = nombre de commits dont `head` (branche amont) est en
// avance sur `base` (révision verrouillée du lock) = le **retard** de l'input.
function compareApiUrl(owner, repo, base, head) {
    return "https://api.github.com/repos/" + owner + "/" + repo + "/compare/" + base + "..." + head;
}

// URL de l'API repo GitHub : GET .../repos/<owner>/<repo>. Sert à résoudre la branche par
// défaut (`default_branch`) d'un input qui ne suit pas de `ref` explicite (cf. model).
function repoApiUrl(owner, repo) {
    return "https://api.github.com/repos/" + owner + "/" + repo;
}
