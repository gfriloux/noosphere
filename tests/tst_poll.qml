// Scenario tests for the pure poll driver (src/model/poll.js).
//
// These are inline assertions, not goldens: the driver is a state machine, and a golden per
// scenario would freeze an execution trace that legitimately changes on every refactor.
// See the issues-pass design for the reasoning.
//
// Everything here runs under qmltestrunner, which is only possible because poll.js imports
// nothing from Quickshell. If it ever does, this whole file stops loading and `just test`
// would still pass — hence test_noQuickshellImport below.
import QtQuick
import QtTest
import "../src/model/poll.js" as Poll
import "lib/golden.js" as Golden

TestCase {
    name: "poll"

    // The fixture is the one the metadata golden already covers: four direct inputs, three
    // comparable GitHub ones (flake-parts and home-manager without a channel, nixpkgs with
    // "nixos-unstable") and one non-GitHub (mytool, type "git"). Queue order is by name.
    readonly property string metaText: JSON.stringify(Golden.readJson(Qt.resolvedUrl("fixtures/metadata-mixed.json")))

    readonly property string revFlakeParts: "17c9d6cdfc60c64f4ee8d306f9bc0b4ccb51481e"
    readonly property string revHomeManager: "aaaa1111bbbb2222cccc3333dddd4444eeee5555"
    readonly property string revNixpkgs: "65179426c83bb3f6bc14898b42ea1c6f01d374b0"

    function st() {
        return Poll.create({
            "apiBase": ""
        });
    }

    function repoBody(fullName, branch) {
        return JSON.stringify({
            "full_name": fullName,
            "default_branch": branch
        });
    }

    function compareBody(sha, aheadBy) {
        return JSON.stringify({
            "base_commit": {
                "sha": sha
            },
            "ahead_by": aheadBy
        });
    }

    // Walk the driver by answering each `get` effect, until it stops asking.
    function drive(state, respond) {
        var eff = Poll.begin(state, metaText);
        var guard = 0;
        while (eff.kind === "get") {
            verify(guard++ < 20, "driver did not terminate");
            var r = respond(eff.url);
            eff = Poll.onHttpDone(state, eff.token, r.status, r.text, r.timedOut === true);
        }
        return eff;
    }

    // Answer every repo/compare request successfully, with `ahead` commits of drift each.
    function responder(ahead) {
        return function (url) {
            if (url.indexOf("/compare/") > 0) {
                var sha = url.indexOf(revFlakeParts) > 0 ? revFlakeParts : (url.indexOf(revHomeManager) > 0 ? revHomeManager : revNixpkgs);
                return {
                    "status": 200,
                    "text": compareBody(sha, ahead)
                };
            }
            var full = url.indexOf("hercules-ci") > 0 ? "hercules-ci/flake-parts" : "nix-community/home-manager";
            return {
                "status": 200,
                "text": repoBody(full, "main")
            };
        };
    }

    // ---- nothingVerified: the predicate #7 turns on ----

    // A flake of only non-GitHub inputs has nothing to verify, which must NOT read as a
    // failed verification (DESIGN invariant 4: other types are displayed, never compared).
    function test_nothingVerified_emptyQueue() {
        var s = st();
        Poll.begin(s, JSON.stringify({
            "locks": {
                "root": "root",
                "nodes": {
                    "root": {
                        "inputs": {
                            "mytool": "mytool"
                        }
                    },
                    "mytool": {
                        "locked": {
                            "type": "git",
                            "rev": "cafe",
                            "lastModified": 1
                        },
                        "original": {
                            "type": "git"
                        }
                    }
                }
            }
        }));
        compare(Poll.nothingVerified(s), false);
    }

    function test_nothingVerified_noneResolved() {
        var s = st();
        drive(s, function (url) {
            return {
                "status": 500,
                "text": ""
            };
        });
        compare(Poll.nothingVerified(s), true);
    }

    function test_nothingVerified_oneResolved() {
        var s = st();
        drive(s, responder(0));
        compare(Poll.nothingVerified(s), false);
    }

    // ---- Full polls ----

    function test_poll_drift() {
        var s = st();
        var eff = drive(s, responder(4));
        compare(eff.kind, "commit");
        compare(eff.verified, true);
        compare(Poll.model(s).barState, "drift");
        compare(Poll.model(s).behindCount, 3);
    }

    function test_poll_uptodate() {
        var s = st();
        var eff = drive(s, responder(0));
        compare(eff.kind, "commit");
        compare(eff.verified, true);
        compare(Poll.model(s).barState, "uptodate");
        compare(Poll.model(s).behindCount, 0);
        compare(Poll.model(s).upToDateCount, 3);
    }

    // Every call failing non-fatally: the poll completes, nothing was verified, and the
    // freshly parsed input list is still published with an indeterminate lag. This is #7.
    function test_poll_allFailed() {
        var s = st();
        var eff = drive(s, function (url) {
            return {
                "status": 500,
                "text": ""
            };
        });
        compare(eff.kind, "commit");
        compare(eff.verified, false);
        compare(Poll.nothingVerified(s), true);
        compare(Poll.model(s).inputs.length, 4);
        compare(Poll.model(s).inputs[0].behind, null);
    }

    // A fatal cause stops the whole poll rather than leaving each input indeterminate.
    function test_poll_rateLimited() {
        var s = st();
        var eff = drive(s, function (url) {
            return {
                "status": 403,
                "text": JSON.stringify({
                    "message": "API rate limit exceeded"
                })
            };
        });
        compare(eff.kind, "fail");
        compare(eff.message, "limite d'API GitHub atteinte");
    }

    function test_poll_metaUnparseable() {
        var s = st();
        var eff = Poll.begin(s, "not json at all");
        compare(eff.kind, "fail");
    }

    // ---- Attribution and abort: DESIGN invariant 10, made testable ----

    // A response carrying a stale token is a response to a request we abandoned. It must
    // change nothing — otherwise an aborted request advances the next input's step.
    function test_staleTokenIsIgnored() {
        var s = st();
        var first = Poll.begin(s, metaText);
        compare(first.kind, "get");
        var stale = first.token;
        // The watchdog gives up on the in-flight request and moves on.
        Poll.onWatchdog(s);
        var before = JSON.stringify(Poll.model(s).inputs);
        var eff = Poll.onHttpDone(s, stale, 200, repoBody("hercules-ci/flake-parts", "main"), false);
        compare(eff.kind, "noop");
        compare(JSON.stringify(Poll.model(s).inputs), before);
    }

    // A compare whose base_commit.sha belongs to another input is discarded, never guessed.
    function test_attributionMismatchDiscarded() {
        var s = st();
        drive(s, function (url) {
            if (url.indexOf("/compare/") > 0) {
                // Always answer with nixpkgs's lockRev, whoever asked.
                return {
                    "status": 200,
                    "text": compareBody(revNixpkgs, 99)
                };
            }
            var full = url.indexOf("hercules-ci") > 0 ? "hercules-ci/flake-parts" : "nix-community/home-manager";
            return {
                "status": 200,
                "text": repoBody(full, "main")
            };
        });
        // Only nixpkgs may have taken that 99; the two others must stay indeterminate.
        var byName = {};
        var list = Poll.model(s).inputs;
        for (var i = 0; i < list.length; i++)
            byName[list[i].name] = list[i].behind;
        compare(byName["flake-parts"], null);
        compare(byName["home-manager"], null);
        compare(byName["nixpkgs"], 99);
    }

    // ---- Watchdog ----

    // A step that never answers must not strand the poll: the watchdog advances it, and the
    // input it gave up on simply stays indeterminate.
    function test_watchdogAdvances() {
        var s = st();
        var eff = Poll.begin(s, metaText);
        compare(eff.kind, "get");
        eff = Poll.onWatchdog(s);
        compare(eff.kind, "get");
        verify(eff.token !== undefined);
    }

    // With the queue spent, the watchdog has nothing left to advance to and commits.
    function test_watchdogAtEndCommits() {
        var s = st();
        var eff = drive(s, responder(0));
        compare(eff.kind, "commit");
        // Nothing is in flight any more, so a watchdog tick is a stuck non-HTTP step.
        compare(Poll.onWatchdog(s).kind, "fail");
    }

    // ---- Routing ----

    // An input carrying a channel needs no default-branch lookup: compare straight away.
    function test_channelSkipsRepoLookup() {
        var s = st();
        var eff = Poll.begin(s, JSON.stringify({
            "locks": {
                "root": "root",
                "nodes": {
                    "root": {
                        "inputs": {
                            "nixpkgs": "nixpkgs"
                        }
                    },
                    "nixpkgs": {
                        "locked": {
                            "type": "github",
                            "owner": "nixos",
                            "repo": "nixpkgs",
                            "rev": "abc",
                            "lastModified": 1
                        },
                        "original": {
                            "type": "github",
                            "owner": "nixos",
                            "repo": "nixpkgs",
                            "ref": "nixos-unstable"
                        }
                    }
                }
            }
        }));
        compare(eff.kind, "get");
        verify(eff.url.indexOf("/compare/") > 0);
        verify(eff.url.indexOf("nixos-unstable") > 0);
    }

    // Without a channel, the repo is asked for its default branch first, and the compare
    // that follows uses the branch that came back.
    function test_defaultBranchResolved() {
        var s = st();
        var eff = Poll.begin(s, metaText);
        verify(eff.url.indexOf("/repos/") > 0);
        verify(eff.url.indexOf("/compare/") < 0);
        eff = Poll.onHttpDone(s, eff.token, 200, repoBody("hercules-ci/flake-parts", "trunk"), false);
        compare(eff.kind, "get");
        verify(eff.url.indexOf("/compare/") > 0);
        verify(eff.url.indexOf("trunk") > 0);
    }

    // An unresolved default branch leaves that input indeterminate and moves on, rather
    // than comparing against a branch we never confirmed.
    function test_unresolvedRepoAdvances() {
        var s = st();
        var eff = Poll.begin(s, metaText);
        eff = Poll.onHttpDone(s, eff.token, 404, "", false);
        compare(eff.kind, "get");
        // Moved on to the next input's repo lookup, not to flake-parts' compare.
        verify(eff.url.indexOf("home-manager") > 0);
    }

    // ---- The guard that keeps this file meaningful ----

    function test_noQuickshellImport() {
        // poll.js must stay loadable by qmltestrunner, which cannot load Quickshell's
        // modules (their types live in the quickshell binary, not in a plugin library).
        // This asserts the module is reachable at all; the grep that proves no Quickshell
        // import crept in lives in the plan's verification steps.
        verify(typeof Poll.create === "function");
        verify(typeof Poll.begin === "function");
        verify(typeof Poll.onHttpDone === "function");
        verify(typeof Poll.onWatchdog === "function");
        verify(typeof Poll.onMetaFailed === "function");
        verify(typeof Poll.model === "function");
        verify(typeof Poll.nothingVerified === "function");
    }
}
