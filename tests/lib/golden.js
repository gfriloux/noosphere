.pragma library

// Synchronous read of a local JSON file (a fixture or a golden) over file:// .
function readJson(url) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.send(null);
    // file:// often reports status 0 on success.
    if (xhr.status !== 200 && xhr.status !== 0)
        throw new Error("cannot read: " + url + " (status " + xhr.status + ")");
    return JSON.parse(xhr.responseText);
}

// Canonical serialisation (keys sorted), so a comparison does not depend on key order.
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
