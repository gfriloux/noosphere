// Régénère les goldens depuis les fixtures via le transform courant de chaque cas.
// Exécuté par `just bless`. Les transforms sont en QML-JS (.pragma library) : seul un
// runtime QML peut les exécuter — quickshell pour la capacité d'écriture fichier.
//
// Vit à la racine du repo : quickshell enracine la config sur le dossier du -p, et les
// imports ne doivent pas en sortir. Racine = repo → `src/` et `tests/` sont tous deux
// accessibles (cases.js importe `../src/model/...`). Lecture relative à ce fichier,
// écriture relative au cwd (= racine du repo, `just` s'y place).
import QtQuick
import Quickshell
import Quickshell.Io
import "tests/cases.js" as Cases
import "tests/lib/golden.js" as Golden

ShellRoot {
    id: root

    QtObject {
        Component.onCompleted: {
            for (var i = 0; i < Cases.cases.length; i++) {
                var c = Cases.cases[i];
                var input = Golden.readJson(Qt.resolvedUrl("tests/fixtures/" + c.name + ".json"));
                var out = Golden.pretty(c.transform(input)) + "\n";
                var fv = Qt.createQmlObject("import Quickshell.Io\nFileView {}", root);
                fv.path = "tests/golden/" + c.name + ".json";
                fv.setText(out);
                console.log("blessed: " + c.name);
            }
        }
    }

    // Laisse les écritures se vider avant de quitter.
    Timer {
        running: true
        interval: 300
        onTriggered: Qt.quit()
    }
}
