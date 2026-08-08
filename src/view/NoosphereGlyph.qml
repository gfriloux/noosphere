// Glyphe identité de noosphere : une rosace/engrenage (roue à 8 rayons + moyeu), clin
// d'œil mécanique de l'Adeptus Mechanicus (cf. DESIGN.md). Dessiné en Canvas pour rester
// net à toute taille et se colorer selon l'état du badge (bleu/jaune/mauve/gris).
//
// Composition (viewBox 24×24, centre 12,12) : quatre barres diamétrales rotées de 45° =
// 8 rayons ; par-dessus un disque plein r=7.4 ; puis un moyeu sombre r=2.9.
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
            // 4 barres diamétrales → 8 rayons.
            for (var i = 0; i < 4; i++) {
                ctx.save();
                ctx.rotate(i * Math.PI / 4);
                roundBar(ctx, -12, -1.4, 24, 2.8, 1.4);
                ctx.fill();
                ctx.restore();
            }
            // Disque plein central.
            ctx.beginPath();
            ctx.arc(0, 0, 7.4, 0, 2 * Math.PI);
            ctx.fill();
            // Moyeu sombre.
            ctx.beginPath();
            ctx.fillStyle = "rgba(0,0,0,0.42)";
            ctx.arc(0, 0, 2.9, 0, 2 * Math.PI);
            ctx.fill();

            ctx.restore();
        }
    }
}
