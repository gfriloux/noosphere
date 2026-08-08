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
    // apiBase vide → base par défaut api.github.com.
    function test_compareApiUrl_default() {
        eq(Q.compareApiUrl("", "nixos", "nixpkgs", "65179426c83bb3f6bc14898b42ea1c6f01d374b0", "nixos-unstable"), "https://api.github.com/repos/nixos/nixpkgs/compare/65179426c83bb3f6bc14898b42ea1c6f01d374b0...nixos-unstable");
    }

    // apiBase surchargé (mock local en dev).
    function test_compareApiUrl_mock() {
        eq(Q.compareApiUrl("http://127.0.0.1:8385", "nixos", "nixpkgs", "abc", "nixos-unstable"), "http://127.0.0.1:8385/repos/nixos/nixpkgs/compare/abc...nixos-unstable");
    }

    function test_repoApiUrl() {
        eq(Q.repoApiUrl("", "hercules-ci", "flake-parts"), "https://api.github.com/repos/hercules-ci/flake-parts");
    }

    // --- Diff de closure (v0.2.0) ---

    // Le path et le host restent des éléments argv distincts (pas de découpage shell).
    function test_buildToplevel() {
        eq(Q.buildToplevel("/etc/nixos", "kuri-desktop"), ["build", "/etc/nixos#nixosConfigurations.kuri-desktop.config.system.build.toplevel", "--no-link", "--print-out-paths"]);
    }

    function test_nvdDiff_default() {
        eq(Q.nvdDiff("", "/nix/store/xxx-nixos-system"), ["diff", "/run/current-system", "/nix/store/xxx-nixos-system"]);
    }
    function test_nvdDiff_explicit() {
        eq(Q.nvdDiff("/run/current-system", "/nix/store/yyy"), ["diff", "/run/current-system", "/nix/store/yyy"]);
    }

    function test_hostnameArgv() {
        eq(Q.hostnameArgv(), ["hostname"]);
    }
}
