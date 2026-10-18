.pragma library

// PRESENTATION helpers. Deliberately OUTSIDE the golden model: they depend on "now"
// (relative time) or are nothing but visual mapping. Tested inline.

// Catppuccin Mocha colours for the badge states (see DESIGN.md).
function stateColor(state) {
    switch (state) {
    case "uptodate":
        return "#89b4fa"; // blue
    case "drift":
        return "#f9e2af"; // yellow
    case "rebuilding":
        return "#cba6f7"; // mauve (future cap)
    default:
        return "#6c7086"; // grey (error / unknown)
    }
}

// Colour of an input row's state dot: yellow when behind, green otherwise.
function inputDotColor(behind) {
    return (typeof behind === "number" && behind > 0) ? "#f9e2af" : "#a6e3a1";
}

// Lag text, right-aligned on an input row.
// null (indeterminate) → "—" ; 0 → "à jour" ; N → "N commits en retard".
function behindLabel(behind) {
    if (typeof behind !== "number")
        return "—";
    if (behind <= 0)
        return "à jour";
    return behind + (behind > 1 ? " commits en retard" : " commit en retard");
}

// Web URL of the GitHub compare (the read-only "changelog" link): the browser opens it.
function compareWebUrl(owner, repo, base, head) {
    return "https://github.com/" + owner + "/" + repo + "/compare/" + base + "..." + head;
}

// Short relative time from a unix timestamp (seconds). `now` in seconds.
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
