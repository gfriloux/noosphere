default:
    @just --list

# Full quality gate. The only source of truth for the gates — pre-commit and CI call in here
# rather than listing recipes of their own.
ci: ci-hermetic lint

# The subset that needs neither DankMaterialShell nor Quickshell nor a network: this is what
# CI runs, because a GitHub runner has no DMS and therefore cannot resolve the QML imports
# (see scripts/qml-import-paths). Naming it here keeps the Justfile the single definition of
# both gates, with the difference between them explicit instead of duplicated in ci.yml.
ci-hermetic: fmt-check check-manifest test

# Formate le QML en place (qmlformat).
fmt:
    @find src -name '*.qml' -print0 2>/dev/null | xargs -0 -r qmlformat -i

# Vérifie le format sans modifier : échoue si un fichier n'est pas formaté.
fmt-check:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    while IFS= read -r -d '' f; do
        if ! diff -q "$f" <(qmlformat "$f") >/dev/null; then
            echo "non formaté : $f"; fail=1
        fi
    done < <(find src -name '*.qml' -print0 2>/dev/null)
    exit $fail

# Static QML lint (qmllint), with every import resolved through Quickshell's own generated
# VFS — see scripts/qml-import-paths for why `-I` alone cannot resolve DMS's qs.* modules.
# Blocking at ZERO output lines.
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    # A failure here (DMS absent, quickshell absent, VFS unobtainable) aborts the recipe:
    # linting a subset in silence is the defect this whole change exists to remove.
    paths="$(scripts/qml-import-paths)"
    args=()
    while IFS= read -r p; do
        case "$p" in /*) args+=(-I "$p") ;; esac
    done <<<"$paths"
    if [ ${#args[@]} -eq 0 ]; then
        echo "lint: no import path resolved — refusing to lint without them" >&2
        exit 1
    fi
    mapfile -t files < <(find src -name '*.qml' | sort)
    if [ ${#files[@]} -eq 0 ]; then
        echo "lint: no QML file found under src/ — refusing to report a pass" >&2
        exit 1
    fi
    set +e
    raw="$(qmllint "${args[@]}" "${files[@]}" 2>&1)"
    rc=$?
    set -e
    # A non-zero exit means the LINTER failed — missing binary, crash, bad argument — not
    # that it found something. Judging only the output would let that pass green, which is
    # the very shape of bug this gate exists to remove.
    if [ "$rc" -ne 0 ]; then
        printf '%s\n' "$raw" >&2
        printf 'lint: qmllint exited %s — the linter did not run; this is not a pass\n' "$rc" >&2
        exit 1
    fi
    # Conversely qmllint exits 0 whatever it *finds*, so the findings themselves are judged
    # from its output, never from its exit code.
    #
    # Two classes are dropped as known-bogus, both artefacts of Quickshell synthesising its
    # module metadata instead of shipping qmldir files. Neither can hide anything about our
    # own code; delete a filter the day its cause is gone.
    findings="$(printf '%s\n' "$raw" \
        | grep -vE 'not declared as singleton in qmldir but using pragma Singleton' \
        | grep -vE 'PostReloadHook was not found' \
        | grep -E 'Warning:|Error:|Info:' || true)"
    if [ -n "$findings" ]; then
        printf '%s\n' "$findings" >&2
        printf 'lint: %s finding(s) — this gate blocks at zero\n' "$(printf '%s\n' "$findings" | grep -c .)" >&2
        exit 1
    fi
    # Say so on success: a gate that is silent when it passes is indistinguishable from a
    # gate that did not run.
    printf 'lint: 0 findings over %s file(s), %s import path(s)\n' "${#files[@]}" "$(( ${#args[@]} / 2 ))"

# Check plugin.json against DankMaterialShell's published schema (vendored under
# tests/vendor/). The manifest is the only written contract between this plugin and its host,
# and this is the one gate CI can run: it needs neither DMS nor Quickshell.
check-manifest:
    @scripts/check-manifest

# Tests golden : qmltestrunner exécute les transforms JS sur fixtures → compare aux goldens.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! find tests -name 'tst_*.qml' 2>/dev/null | grep -q .; then
        echo "aucun test (tests/tst_*.qml absent)"; exit 0
    fi
    # QtTest (TestCase) importe QtQuick.Window : on pointe explicitement le dossier qml de
    # qtdeclarative (sinon, en CI sans QML2_IMPORT_PATH ambiant, le module est introuvable).
    qmldir="$(dirname "$(dirname "$(command -v qmltestrunner)")")/lib/qt-6/qml"
    export QML2_IMPORT_PATH="$qmldir${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 qmltestrunner -input tests

# Régénère les goldens depuis les fixtures (transform courant). Relire le diff ensuite.
bless:
    QML_XHR_ALLOW_FILE_READ=1 quickshell -p bless.qml

# Serveur mock du compare GitHub pour le dev (aucun réseau requis). scenario :
# drift | uptodate | ratelimit | error. Régler l'endpoint GitHub du plugin sur
# http://127.0.0.1:<port>.
mock scenario="drift" port="8385":
    @python3 scripts/github-mock.py {{ port }} {{ scenario }}

# Lance une instance DMS *isolée* chargeant le worktree comme plugin « Noosphere (dev) »,
# sans toucher au DMS quotidien. Combiner avec `just mock` dans un autre terminal.
dev-bar:
    @scripts/noosphere-dev "{{ justfile_directory() }}"

# Prepend the section for the version in plugin.json to CHANGELOG.md (git-cliff). Read the
# diff afterwards.
#
# This PREPENDS; it does not regenerate. Regenerating would re-emit the v0.1.0 … v0.3.0
# sections — which describe commits written in French — under cliff.toml's English group
# headers, rewriting the published record. Bump plugin.json first, then run this.
changelog:
    #!/usr/bin/env bash
    set -euo pipefail
    version="v$(jq -r .version plugin.json)"
    if grep -qF "## [${version#v}]" CHANGELOG.md; then
        echo "changelog: ${version} already has a section — nothing to prepend" >&2
        exit 1
    fi
    git-cliff --unreleased --tag "$version" --prepend CHANGELOG.md
