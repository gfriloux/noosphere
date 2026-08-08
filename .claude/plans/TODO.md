# TODO — chantiers identifiés, pas encore planifiés

Backlog des sujets repérés en cours de route. Chacun devient un `.claude/plans/v{X.Y.Z}/`
quand il est pris. Un sujet traité disparaît d'ici (il vit alors dans son plan et le
changelog), il n'est pas barré sur place.

---

## Réparer la porte `lint`

**Repéré :** 2026-08-08, audit phase 0 de v0.3.0.
**Gravité :** élevée — une porte annoncée qui ne garde rien.

`CLAUDE.md` et le `Justfile` annoncent « qmllint, aucun warning toléré ». Mesuré sur
`main` @ `2f3a707` :

| | |
|---|---|
| `just lint` | exit **0** |
| warnings émis | **745** |

Répartition : `Cockpit.qml` 304, `ClosureCard.qml` 230, `Noosphere.qml` 74,
`NoosphereWidget.qml` 66, `Closure.qml` 41, `Settings.qml` 15, `NoosphereGlyph.qml` 9.

**Cause racine :** `qmllint` est invoqué sans chemin d'import (`-I`) vers les modules
Quickshell et QtQuick. Il échoue donc dès `import QtQuick` / `import Quickshell.Io`
(« Failed to import QtQuick. Are your import paths set up properly? »), et tout cascade
en `Process was not found`, `unresolved-type`, `unqualified`. Le code n'est pas fautif :
c'est l'outil qui ne voit rien. Et `qmllint` rend malgré tout 0, donc `just ci` reste vert.

**Conséquence :** aucune régression QML n'est détectable par la CI. Le travail sur
`Noosphere.qml` en v0.3.0 s'est validé sur `just test` (couche `model`) et les tests
manuels, faute de mieux.

**Pistes pour le plan à venir :**
- passer les chemins d'import à `qmllint` (`-I` vers le `qml/` de Quickshell et de Qt6,
  cf. la cible `test` du `Justfile` qui résout déjà un cas voisin) ;
- vérifier ensuite ce que rend `qmllint` **une fois les imports résolus** : il restera
  probablement un passif réel, à mesurer avant de décider ;
- rendre l'échec bloquant (`--warnings error` ou contrôle du code de sortie dans la
  recette), sinon la porte reste décorative ;
- résorber le passif restant, éventuellement fichier par fichier.

À faire dans cet ordre : sans les `-I`, mesurer le passif réel est impossible.

---

## Requêtes conditionnelles `If-None-Match` / `ETag`

**Repéré :** 2026-08-08, étude du transport (v0.3.0). Écarté du périmètre à dessein.

Vérifié fonctionnel sous Qt 6.11.1 (304 reçu, corps vide). **Gain :** un poll sur un flake
stable ne consommerait presque plus de quota — ce qui compte surtout **sans** token
(60 req/h face à ~15 requêtes par poll). **Coût :** un cache mémoire des ETags dans le
service, donc un état supplémentaire à invalider (et à ne pas persister : invariant DESIGN 1).

---

## Paralléliser les compare GitHub

**Repéré :** 2026-08-08, étude du transport (v0.3.0). Écarté du périmètre à dessein.

Le séquentiel est un choix (budget de requêtes, simplicité, précédent v0.2.1). Le passage
à XHR le rend techniquement possible — un objet par requête, plus de `Process` partagé.
**Gain :** la latence d'un poll (~15 requêtes en série). **Coût :** un contrôle de
concurrence, un timer par requête en vol, et un comportement de rate-limit à repenser
(plusieurs requêtes déjà parties quand le 403 arrive).
