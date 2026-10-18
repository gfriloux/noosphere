// Regenerates the goldens from the fixtures through each case's current transform.
// Run by `just bless`. The transforms are QML-JS (.pragma library), so only a QML runtime
// can execute them — quickshell, for its file-writing capability.
//
// It lives at the repository root: quickshell roots the config on the -p directory, and the
// imports must not escape that root. Root = the repository → both `src/` and `tests/` are
// reachable (cases.js imports `../src/model/...`). Reads are relative to this file, writes
// relative to the cwd — the repository root, where `just` places itself.
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

    // Let the writes flush before quitting.
    Timer {
        running: true
        interval: 300
        onTriggered: Qt.quit()
    }
}
