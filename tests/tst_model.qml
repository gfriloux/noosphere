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

    // ---- githubError : statut HTTP → cause nommée ----
    //
    // `fatal` dit si la cause vaut pour toutes les requêtes suivantes (inutile de marteler
    // l'API : le poll s'arrête) ou si elle ne concerne que cet input (on avance).

    function test_githubError_ok() {
        compare(Model.githubError(200, "{}", false), null);
        compare(Model.githubError(204, "", false), null);
    }
    function test_githubError_rateLimit() {
        var e = Model.githubError(403, '{"message": "API rate limit exceeded for 1.2.3.4."}', false);
        compare(e.fatal, true);
        verify(e.message.indexOf("limite") >= 0);
        // 429 : limite secondaire, même conduite quel que soit le corps.
        compare(Model.githubError(429, "{}", false).fatal, true);
    }
    function test_githubError_forbiddenSansLimite() {
        // Un 403 qui n'est pas une limite de débit ne doit pas être annoncé comme telle.
        var e = Model.githubError(403, '{"message": "Resource not accessible"}', false);
        compare(e.fatal, true);
        compare(e.message.indexOf("limite"), -1);
    }
    function test_githubError_token() {
        var e = Model.githubError(401, '{"message": "Bad credentials"}', false);
        compare(e.fatal, true);
        verify(e.message.indexOf("token") >= 0);
    }
    function test_githubError_notFound() {
        // Propre à un input : les autres restent comparables.
        var e = Model.githubError(404, '{"message": "Not Found"}', false);
        compare(e.fatal, false);
    }
    function test_githubError_serveur() {
        compare(Model.githubError(500, "", false).fatal, false);
        compare(Model.githubError(503, "", false).fatal, false);
    }
    function test_githubError_transport() {
        // status 0 couvre deux causes distinctes, que seul le drapeau sépare.
        var timeout = Model.githubError(0, "", true);
        var reseau = Model.githubError(0, "", false);
        compare(timeout.fatal, false);
        compare(reseau.fatal, false);
        verify(timeout.message !== reseau.message);
        verify(timeout.message.indexOf("délai") >= 0);
    }
    function test_githubError_corpsIllisible() {
        // Un corps non-JSON ne doit pas faire échouer la traduction.
        var e = Model.githubError(403, "<html>gateway</html>", false);
        compare(e.fatal, true);
        verify(e.message.length > 0);
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
