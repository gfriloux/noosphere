.pragma library
.import "../src/model/inputs.js" as Model
.import "../src/model/closure.js" as Closure

// Registre unique des cas golden, consommé par tst_golden.qml ET bless.qml.
// Chaque cas : { name, transform } avec fixtures/<name>.json → golden/<name>.json.

// Sortie `nix flake metadata --json` figée → inputs directs (parseMetadata).
function metadataCase(input) {
    return Model.parseMetadata(input);
}

// { inputs (déjà parsés), behind (map name→retard) } → inputs annotés (mergeBehind).
function mergeCase(input) {
    return Model.mergeBehind(input.inputs, input.behind);
}

// { text } = sortie `nvd diff` figée → modèle de closure (parseNvdDiff).
function nvdCase(input) {
    return Closure.parseNvdDiff(input.text);
}

var cases = [
    {
        "name": "metadata-mixed",
        "transform": metadataCase
    },
    {
        "name": "merge-drift",
        "transform": mergeCase
    },
    {
        "name": "nvd-changes",
        "transform": nvdCase
    },
    {
        "name": "nvd-reboot",
        "transform": nvdCase
    },
    {
        "name": "nvd-empty",
        "transform": nvdCase
    }
];
