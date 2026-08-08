.pragma library

// Lecture synchrone d'un JSON local (fixture ou golden) via file:// .
function readJson(url) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.send(null);
    // file:// renvoie souvent status 0 en cas de succès.
    if (xhr.status !== 200 && xhr.status !== 0)
        throw new Error("lecture impossible: " + url + " (status " + xhr.status + ")");
    return JSON.parse(xhr.responseText);
}

// Sérialisation canonique (clés triées) pour comparer indépendamment de l'ordre.
function canonical(v) {
    if (Array.isArray(v))
        return "[" + v.map(canonical).join(",") + "]";
    if (v && typeof v === "object") {
        var keys = Object.keys(v).sort();
        return "{" + keys.map(function (k) {
            return JSON.stringify(k) + ":" + canonical(v[k]);
        }).join(",") + "}";
    }
    return JSON.stringify(v);
}

function equal(a, b) {
    return canonical(a) === canonical(b);
}

function pretty(v) {
    return JSON.stringify(v, null, 2);
}
