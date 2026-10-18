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

// Web URL of the GitHub compare (the read-only "changelog" link): the browser opens it.
function compareWebUrl(owner, repo, base, head) {
    return "https://github.com/" + owner + "/" + repo + "/compare/" + base + "..." + head;
}

// Relative age from a unix timestamp (seconds); `now` in seconds. Returns the **parts** of
// the age, never a sentence: { unit, value } with unit ∈ now | minutes | hours | days. The
// view turns that into words, so the wording is translatable and this layer stays pure.
// A timestamp in the future clamps to `now` rather than going negative.
function relativeAgeParts(tsSeconds, nowSeconds) {
    var d = Math.max(0, Math.floor(nowSeconds - tsSeconds));
    if (d < 60)
        return {
            "unit": "now",
            "value": 0
        };
    var mins = Math.floor(d / 60);
    if (mins < 60)
        return {
            "unit": "minutes",
            "value": mins
        };
    var hours = Math.floor(mins / 60);
    if (hours < 24)
        return {
            "unit": "hours",
            "value": hours
        };
    return {
        "unit": "days",
        "value": Math.floor(hours / 24)
    };
}
