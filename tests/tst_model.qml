import QtQuick
import QtTest
import "../src/model/inputs.js" as Model
import "../src/model/format.js" as Format
import "../src/model/closure.js" as Closure

TestCase {
    name: "model"

    // ---- closure : sévérité (le parse complet est golden-testé) ----

    function test_closureSeverity_reboot() {
        compare(Closure.closureSeverity("linux"), "reboot");
        compare(Closure.closureSeverity("linux-firmware"), "reboot");
        compare(Closure.closureSeverity("sof-firmware"), "reboot");
        compare(Closure.closureSeverity("mesa"), "reboot");
        compare(Closure.closureSeverity("nvidia-x11"), "reboot");
        compare(Closure.closureSeverity("intel-microcode"), "reboot");
    }
    function test_closureSeverity_neutral() {
        compare(Closure.closureSeverity("firefox"), "neutral");
        compare(Closure.closureSeverity("curl"), "neutral");
        compare(Closure.closureSeverity(""), "neutral");
    }
    function test_cardSeverity() {
        compare(Closure.cardSeverity([
            {
                "severity": "neutral"
            },
            {
                "severity": "reboot"
            }
        ]), "reboot");
        compare(Closure.cardSeverity([
            {
                "severity": "neutral"
            }
        ]), "neutral");
        compare(Closure.cardSeverity([]), "neutral");
    }

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

    // Une réponse compare n'est exploitable que si elle porte bien sur la révision
    // verrouillée de l'input attendu : sinon elle vient d'une requête d'un autre input
    // (réponse tardive, étape sautée) et l'enregistrer attribuerait son retard au voisin.
    function test_compareBelongsTo_match() {
        compare(Model.compareBelongsTo({
            "base_commit": {
                "sha": "b22513e907a3efc7870bffeefbca0625a56ca460"
            },
            "ahead_by": 11
        }, "b22513e907a3efc7870bffeefbca0625a56ca460"), true);
    }
    function test_compareBelongsTo_otherInput() {
        compare(Model.compareBelongsTo({
            "base_commit": {
                "sha": "e8e87e6aa191072d5e9de1d483dd47999c88f642"
            },
            "ahead_by": 11
        }, "b22513e907a3efc7870bffeefbca0625a56ca460"), false);
    }
    function test_compareBelongsTo_errorResponse() {
        compare(Model.compareBelongsTo({
            "message": "API rate limit exceeded"
        }, "b22513e907a3efc7870bffeefbca0625a56ca460"), false);
        compare(Model.compareBelongsTo(null, "b22513e907a3efc7870bffeefbca0625a56ca460"), false);
    }
    function test_compareBelongsTo_noLockRev() {
        compare(Model.compareBelongsTo({
            "base_commit": {
                "sha": "b22513e907a3efc7870bffeefbca0625a56ca460"
            }
        }, ""), false);
    }

    function test_parseDefaultBranch() {
        compare(Model.parseDefaultBranch({
            "default_branch": "master"
        }), "master");
        compare(Model.parseDefaultBranch({}), "");
    }

    function test_repoBelongsTo() {
        compare(Model.repoBelongsTo({
            "full_name": "gfriloux/stc",
            "default_branch": "main"
        }, "gfriloux", "stc"), true);
        compare(Model.repoBelongsTo({
            "full_name": "gfriloux/pgpilot",
            "default_branch": "main"
        }, "gfriloux", "stc"), false);
        compare(Model.repoBelongsTo({
            "message": "Not Found"
        }, "gfriloux", "stc"), false);
        compare(Model.repoBelongsTo(null, "gfriloux", "stc"), false);
        compare(Model.repoBelongsTo({
            "full_name": "gfriloux/stc"
        }, "", "stc"), false);
    }

    // ---- githubError: HTTP status → a named cause ----
    //
    // It returns a `code`, never a sentence: the view turns the code into words, so the
    // wording can be translated and this layer stays pure. `fatal` says whether the cause
    // holds for every later request — no point hammering the API, the poll stops — or
    // concerns only this input, in which case the poll advances.

    function test_githubError_ok() {
        compare(Model.githubError(200, "{}", false), null);
        compare(Model.githubError(204, "", false), null);
    }
    function test_githubError_rateLimit() {
        var e = Model.githubError(403, '{"message": "API rate limit exceeded for 1.2.3.4."}', false);
        compare(e.code, "rate-limited");
        compare(e.fatal, true);
        // 429: the secondary limit, same conduct whatever the body says.
        compare(Model.githubError(429, "{}", false).code, "rate-limited");
        compare(Model.githubError(429, "{}", false).fatal, true);
    }
    function test_githubError_forbiddenWithoutRateLimit() {
        // A 403 that is not a rate limit must not be reported as one.
        var e = Model.githubError(403, '{"message": "Resource not accessible"}', false);
        compare(e.code, "forbidden");
        compare(e.fatal, true);
    }
    function test_githubError_token() {
        var e = Model.githubError(401, '{"message": "Bad credentials"}', false);
        compare(e.code, "token-refused");
        compare(e.fatal, true);
    }
    function test_githubError_notFound() {
        // Specific to one input: the others stay comparable.
        var e = Model.githubError(404, '{"message": "Not Found"}', false);
        compare(e.code, "not-found");
        compare(e.fatal, false);
    }
    function test_githubError_server() {
        // The status travels with the code so the view can render "(503)".
        var e = Model.githubError(503, "", false);
        compare(e.code, "unavailable");
        compare(e.fatal, false);
        compare(e.status, 503);
        compare(Model.githubError(500, "", false).code, "unavailable");
    }
    function test_githubError_unexpectedStatus() {
        var e = Model.githubError(418, "", false);
        compare(e.code, "unexpected");
        compare(e.fatal, false);
        compare(e.status, 418);
    }
    function test_githubError_transport() {
        // status 0 covers two distinct causes, which only the flag separates.
        var timeout = Model.githubError(0, "", true);
        var offline = Model.githubError(0, "", false);
        compare(timeout.code, "timeout");
        compare(offline.code, "offline");
        compare(timeout.fatal, false);
        compare(offline.fatal, false);
    }
    function test_githubError_unreadableBody() {
        // A non-JSON body must not break the classification.
        var e = Model.githubError(403, "<html>gateway</html>", false);
        compare(e.code, "forbidden");
        compare(e.fatal, true);
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

    function test_compareWebUrl() {
        compare(Format.compareWebUrl("gfriloux", "nixos", "abc", "main"), "https://github.com/gfriloux/nixos/compare/abc...main");
    }

    // Parts, not prose: the view turns { unit, value } into a translated sentence.
    function test_relativeAgeParts() {
        compare(Format.relativeAgeParts(1000, 1030).unit, "now");
        var m = Format.relativeAgeParts(1000, 1000 + 5 * 60);
        compare(m.unit, "minutes");
        compare(m.value, 5);
        var h = Format.relativeAgeParts(1000, 1000 + 3 * 3600);
        compare(h.unit, "hours");
        compare(h.value, 3);
        var d = Format.relativeAgeParts(1000, 1000 + 9 * 86400);
        compare(d.unit, "days");
        compare(d.value, 9);
    }

    // A timestamp in the future must not produce a negative age.
    function test_relativeAgeParts_future() {
        compare(Format.relativeAgeParts(2000, 1000).unit, "now");
    }
}
