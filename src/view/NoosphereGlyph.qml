// noosphere's identity glyph: a rosette/gear (an 8-spoke wheel + hub), the discreet
// Adeptus Mechanicus nod (see DESIGN.md). Drawn on a Canvas so it stays crisp at any size
// and takes the badge's state colour (blue/yellow/mauve/grey).
//
// Composition (24×24 viewBox, centre 12,12): four diametral bars rotated by 45° = 8 spokes;
// a filled disc r=7.4 over them; then a dark hub r=2.9.
import QtQuick

Item {
    id: glyph

    property color color: "#89b4fa"
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    onColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        function roundBar(ctx, x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var s = width / 24;
            ctx.save();
            ctx.scale(s, s);
            ctx.translate(12, 12);

            ctx.fillStyle = glyph.color;
            // 4 diametral bars → 8 spokes.
            for (var i = 0; i < 4; i++) {
                ctx.save();
                ctx.rotate(i * Math.PI / 4);
                roundBar(ctx, -12, -1.4, 24, 2.8, 1.4);
                ctx.fill();
                ctx.restore();
            }
            // Central filled disc.
            ctx.beginPath();
            ctx.arc(0, 0, 7.4, 0, 2 * Math.PI);
            ctx.fill();
            // Dark hub.
            ctx.beginPath();
            ctx.fillStyle = "rgba(0,0,0,0.42)";
            ctx.arc(0, 0, 2.9, 0, 2 * Math.PI);
            ctx.fill();

            ctx.restore();
        }
    }
}
