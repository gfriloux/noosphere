default:
    @just --list

# Porte de qualité complète : format + lint + test. Seule source de vérité des gates.
ci: fmt-check lint test

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
# NOT YET BLOCKING: qmllint exits 0 whatever it finds, and making this recipe fail is the
# next step of the issues-pass plan. It reports, for now.
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
    find src -name '*.qml' -print0 2>/dev/null | xargs -0 -r qmllint "${args[@]}"

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

# Régénère le changelog depuis les Conventional Commits (git-cliff). Relire le diff.
changelog:
    @git-cliff --output CHANGELOG.md
