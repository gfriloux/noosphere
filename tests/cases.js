.pragma library
.import "../src/model/inputs.js" as Model

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

var cases = [
    {
        "name": "metadata-mixed",
        "transform": metadataCase
    },
    {
        "name": "merge-drift",
        "transform": mergeCase
    }
];
