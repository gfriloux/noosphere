.pragma library

// Helpers de PRÉSENTATION. Volontairement HORS du modèle golden : ils dépendent de
// « maintenant » (temps relatif) ou ne sont que du mapping visuel. Testés inline.

// Couleurs Catppuccin Mocha des états du badge (cf. DESIGN.md).
function stateColor(state) {
    switch (state) {
    case "uptodate":
        return "#89b4fa"; // bleu
    case "drift":
        return "#f9e2af"; // jaune
    case "rebuilding":
        return "#cba6f7"; // mauve (cap futur)
    default:
        return "#6c7086"; // gris (erreur / inconnu)
    }
}

// Couleur du point d'état d'une ligne d'input : jaune si en retard, vert sinon.
function inputDotColor(behind) {
    return (typeof behind === "number" && behind > 0) ? "#f9e2af" : "#a6e3a1";
}

// Texte de retard aligné à droite d'une ligne d'input.
// null (indéterminé) → "—" ; 0 → "à jour" ; N → "N commits en retard".
function behindLabel(behind) {
    if (typeof behind !== "number")
        return "—";
    if (behind <= 0)
        return "à jour";
    return behind + (behind > 1 ? " commits en retard" : " commit en retard");
}

// URL web du compare GitHub (lien « changelog », lecture seule) : le navigateur l'ouvre.
function compareWebUrl(owner, repo, base, head) {
    return "https://github.com/" + owner + "/" + repo + "/compare/" + base + "..." + head;
}

// Temps relatif court en français depuis un timestamp unix (secondes). `now` en secondes.
// « à l'instant » · « il y a 12 min » · « il y a 3 h » · « il y a 9 j ».
function relativeAge(tsSeconds, nowSeconds) {
    var d = Math.max(0, Math.floor(nowSeconds - tsSeconds));
    if (d < 60)
        return "à l'instant";
    var mins = Math.floor(d / 60);
    if (mins < 60)
        return "il y a " + mins + " min";
    var hours = Math.floor(mins / 60);
    if (hours < 24)
        return "il y a " + hours + " h";
    var days = Math.floor(hours / 24);
    return "il y a " + days + " j";
}
