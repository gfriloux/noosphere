import QtQuick
import QtTest
import "../src/query/queries.js" as Q

TestCase {
    name: "queries"

    function eq(actual, expected) {
        compare(JSON.stringify(actual), JSON.stringify(expected));
    }

    // Sans chemin → flake du répertoire courant.
    function test_flakeMetadata_noPath() {
        eq(Q.flakeMetadata(), ["flake", "metadata", "--json"]);
    }

    // Le chemin (potentiellement avec espaces) reste UN seul argv (pas de découpage shell).
    function test_flakeMetadata_path() {
        eq(Q.flakeMetadata("/home/kuri/my nixos"), ["flake", "metadata", "--json", "/home/kuri/my nixos"]);
    }

    // base...head : base = rev verrouillé, head = branche amont. ahead_by = retard.
    function test_compareApiUrl() {
        eq(Q.compareApiUrl("nixos", "nixpkgs", "65179426c83bb3f6bc14898b42ea1c6f01d374b0", "nixos-unstable"), "https://api.github.com/repos/nixos/nixpkgs/compare/65179426c83bb3f6bc14898b42ea1c6f01d374b0...nixos-unstable");
    }

    function test_repoApiUrl() {
        eq(Q.repoApiUrl("hercules-ci", "flake-parts"), "https://api.github.com/repos/hercules-ci/flake-parts");
    }
}
