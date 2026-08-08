import QtQuick
import QtTest
import "../src/model/inputs.js" as Model
import "../src/model/format.js" as Format

TestCase {
    name: "model"

    // ---- parseCompare / parseDefaultBranch / upstreamRef ----

    function test_parseCompare_ahead() {
        compare(Model.parseCompare({
            "ahead_by": 214,
            "status": "ahead"
        }), 214);
    }
    function test_parseCompare_uptodate() {
        compare(Model.parseCompare({
            "ahead_by": 0
        }), 0);
    }
    function test_parseCompare_missing() {
        compare(Model.parseCompare({
            "message": "rate limit"
        }), null);
        compare(Model.parseCompare(null), null);
    }

    function test_parseDefaultBranch() {
        compare(Model.parseDefaultBranch({
            "default_branch": "master"
        }), "master");
        compare(Model.parseDefaultBranch({}), "");
    }

    function test_upstreamRef() {
        compare(Model.upstreamRef({
            "channel": "nixos-unstable"
        }, "main"), "nixos-unstable");
        compare(Model.upstreamRef({
            "channel": ""
        }, "main"), "main");
    }

    // ---- behindCount / upToDateCount / barState ----

    property var sample: [
        {
            "name": "a",
            "behind": 3
        },
        {
            "name": "b",
            "behind": 0
        },
        {
            "name": "c",
            "behind": null
        },
        {
            "name": "d",
            "behind": 12
        }
    ]

    function test_behindCount() {
        compare(Model.behindCount(sample), 2);
    }
    function test_upToDateCount() {
        compare(Model.upToDateCount(sample), 1);
    }
    function test_barState_drift() {
        compare(Model.barState(sample, false), "drift");
    }
    function test_barState_uptodate() {
        compare(Model.barState([
            {
                "behind": 0
            },
            {
                "behind": null
            }
        ], false), "uptodate");
    }
    function test_barState_rebuilding() {
        compare(Model.barState(sample, true), "rebuilding");
    }

    function test_parseGeneration() {
        compare(Model.parseGeneration("/nix/var/nix/profiles/system-142-link"), 142);
        compare(Model.parseGeneration("/nix/var/nix/profiles/system"), 0);
    }

    // ---- format ----

    function test_stateColor() {
        compare(Format.stateColor("uptodate"), "#89b4fa");
        compare(Format.stateColor("drift"), "#f9e2af");
        compare(Format.stateColor("boom"), "#6c7086");
    }

    function test_behindLabel() {
        compare(Format.behindLabel(null), "—");
        compare(Format.behindLabel(0), "à jour");
        compare(Format.behindLabel(1), "1 commit en retard");
        compare(Format.behindLabel(214), "214 commits en retard");
    }

    function test_compareWebUrl() {
        compare(Format.compareWebUrl("gfriloux", "nixos", "abc", "main"), "https://github.com/gfriloux/nixos/compare/abc...main");
    }

    function test_relativeAge() {
        compare(Format.relativeAge(1000, 1030), "à l'instant");
        compare(Format.relativeAge(1000, 1000 + 5 * 60), "il y a 5 min");
        compare(Format.relativeAge(1000, 1000 + 3 * 3600), "il y a 3 h");
        compare(Format.relativeAge(1000, 1000 + 9 * 86400), "il y a 9 j");
    }
}
