import QtQuick
import QtTest
import "lib/golden.js" as Golden
import "cases.js" as Cases

TestCase {
    name: "golden"

    function test_goldens() {
        for (var i = 0; i < Cases.cases.length; i++) {
            var c = Cases.cases[i];
            var input = Golden.readJson(Qt.resolvedUrl("fixtures/" + c.name + ".json"));
            var expected = Golden.readJson(Qt.resolvedUrl("golden/" + c.name + ".json"));
            var actual = c.transform(input);
            verify(Golden.equal(actual, expected), "golden '" + c.name + "' ne correspond pas\n" + "--- attendu ---\n" + Golden.pretty(expected) + "\n" + "--- obtenu ---\n" + Golden.pretty(actual));
        }
    }
}
