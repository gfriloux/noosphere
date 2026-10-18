.pragma library
.import "../src/model/inputs.js" as Model
.import "../src/model/closure.js" as Closure

// The single registry of golden cases, read by tst_golden.qml AND bless.qml.
// One case: { name, transform }, with fixtures/<name>.json → golden/<name>.json.

// Frozen `nix flake metadata --json` output → the direct inputs (parseMetadata).
function metadataCase(input) {
    return Model.parseMetadata(input);
}

// { inputs (already parsed), behind (name → how far behind) } → annotated inputs (mergeBehind).
function mergeCase(input) {
    return Model.mergeBehind(input.inputs, input.behind);
}

// { text } = frozen `nvd diff` output → the closure model (parseNvdDiff).
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
