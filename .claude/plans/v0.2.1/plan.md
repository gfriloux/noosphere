## Plan : v0.2.1 — fiabiliser le driver de poll et cesser de mentir sur la carte closure

**Type :** bug
**Objectif :** qu'une réponse GitHub ne puisse jamais être attribuée au mauvais input, qu'un
poll ne puisse jamais rester bloqué, et que la carte closure ne contredise plus la liste des
inputs affichée juste au-dessus.
**Pourquoi :** un input affiché « 11 commits en retard » n'apparaissait pas dans l'aperçu de
mise à jour, la carte annonçant « aucun input en retard ». Voir `phase0_results.md`.
**Étage(s) :** `model`, `view`, `doc`

### Contexte

`src/view/Noosphere.qml` pilote les appels séquentiellement : pour chaque input github, un
`GET /repos/…` (si aucune `ref` suivie) puis un `GET /compare/…`. Trois défauts, tous
reproduits en forçant des timeouts curl (`--max-time` abaissé) :

1. **Double avance.** `_advance()` est atteignable deux fois pour une même étape :
   `onExited` (code ≠ 0) *et* `stdout.onStreamFinished` l'appellent tous les deux. Le curseur
   saute un input.
2. **Attribution par curseur.** Les handlers relisent `root._queue[root._cursor]` au lieu de
   l'input pour lequel la requête a été émise. Après une avance parasite, la réponse est
   attribuée au **voisin** — qui affiche alors un retard qu'il n'a pas gagné et pour lequel
   `_heads` n'a jamais été renseigné. Cet input a donc `behind > 0` et `head === ""` : il
   disparaît de `closureOverrides` **et** de la puce « changelog ». C'est exactement le
   symptôme observé.

   Trace obtenue (`NOO_MAXTIME=0.35`) :
   ```
   cmp.exited code=28 cursor=5 → _advance → 6
   repo.stdout cursor=6 it=pgpilot → _advance → 7
   repo.exited code=28 cursor=7 → _advance → 8
   cmp.stdout cursor=8 attribue a sops-nix   ← réponse d'un autre input
   ```
3. **`_busy` sans issue.** `_busy` n'est remis à `false` que dans `_commit()` / `_fail()`. Un
   poll qui n'atteint ni l'un ni l'autre rend « check maintenant » **définitivement muet**.

S'y ajoute un défaut d'IHM : la carte closure déduit son état vide du seul `overrides.length`,
donc elle affirme « aucun input en retard » alors que la liste juste au-dessus en montre un.

### Périmètre

**In scope**
- Fiabilisation du driver séquentiel (`src/view/Noosphere.qml`).
- Prédicat pur d'appartenance d'une réponse compare (`src/model/inputs.js`).
- `--max-time` des appels GitHub porté de 10 s à 20 s.
- Troisième état de la carte closure (`src/view/ClosureCard.qml`, `src/view/Cockpit.qml`).

**Out of scope**
- Toute écriture (`nix flake update`, `nixos-rebuild`, rollback) — invariant DESIGN.
- Paralléliser les appels GitHub. Le séquentiel reste volontaire (budget de requêtes,
  simplicité) ; on le rend correct, on ne le remplace pas.
- Refonte de la carte closure au-delà du troisième état.

### Fichiers touchés

- [ ] `src/model/inputs.js` — `compareBelongsTo()`, `repoBelongsTo()`
- [ ] `src/view/Noosphere.qml` — driver, `--max-time`, watchdog
- [ ] `src/view/ClosureCard.qml` — troisième état idle
- [ ] `src/view/Cockpit.qml` — passe le nombre d'inputs en retard à la carte
- [ ] `tests/tst_model.qml` — couverture de `compareBelongsTo`
- [ ] `.claude/plans/v0.2.1/manual_tests.md`
- [ ] `DESIGN.md` — section driver de poll

### Étapes atomiques

#### Étape 1 : test de régression sur l'appartenance d'une réponse compare
**Description :** ajouter dans `tests/tst_model.qml` la couverture de `compareBelongsTo(res, lockRev)` :
vrai si `res.base_commit.sha === lockRev`, faux si le sha diffère, si la réponse est une erreur
(rate-limit, 404) ou si `lockRev` est vide. Le test échoue (fonction absente).
**Vérification :** `just test` échoue sur `test_compareBelongsTo*`
**Commit :** `test(model): reproduire l'attribution d'une réponse compare au mauvais input`

#### Étape 2 : le modèle sait rejeter une réponse qui n'est pas la sienne
**Description :** implémenter `compareBelongsTo()` dans `src/model/inputs.js` (fonction pure,
documentée comme les voisines).
**Vérification :** `just ci`
**Commit :** `fix(model): rejeter une réponse compare qui n'appartient pas à l'input attendu`

#### Étape 3 : driver séquentiel fiable
**Description :** dans `src/view/Noosphere.qml` —
- `_current` : l'input est **capturé à l'émission** de la requête ; les handlers ne relisent
  plus `_queue[_cursor]` ;
- `_await` (`""` | `"repo"` | `"compare"`) : une étape n'avance qu'une fois ; toute réponse ou
  sortie de processus qui ne correspond pas à l'attente courante est ignorée ;
- la réponse compare est validée par `compareBelongsTo(res, _current.lockRev)` et la réponse
  repo par `repoBelongsTo(res, owner, repoName)` avant d'être exploitées — ajout en cours de
  route : le `GET /repos/…` souffre du même défaut d'attribution que le compare, le corriger
  d'un seul côté aurait laissé la moitié du chemin ouverte ;
- `--max-time` porté à 20 s.
**Vérification :** `just ci` + `manual_tests.md` §1 (mock `drift`, `ratelimit`, `error`)
**Commit :** `fix(view): attribuer chaque réponse GitHub à l'input qui l'a demandée`

#### Étape 4 : un poll ne peut plus rester bloqué
**Description :** watchdog par étape (délai > `--max-time`, marge incluse) : si l'étape ne rend
pas la main, on la déclare indéterminée et on avance. `_busy` retombe dans tous les chemins de
sortie. « check maintenant » redevient toujours opérant.
**Vérification :** `just ci` + `manual_tests.md` §2 (couper le réseau pendant un poll)
**Commit :** `fix(view): garantir la sortie de l'état occupé du poll`

#### Étape 5 : la carte closure ne ment plus
**Description :** trois états au lieu de deux quand `status === "idle"` :

| Situation | Rendu |
|---|---|
| aucun input en retard | `aucun input en retard — rien à prévisualiser` *(inchangé)* |
| des inputs en retard, prévisualisables | bouton `prévisualiser la mise à jour (N)` *(inchangé)* |
| des inputs en retard, aucun prévisualisable | `N inputs en retard — amont non résolu, rien à prévisualiser` |

`Cockpit.qml` passe `behindCount` à `ClosureCard`. Accord singulier/pluriel sur `input(s)`.
**Vérification :** `just ci` + `manual_tests.md` §3 (relecture visuelle des trois états)
**Commit :** `fix(view): distinguer « aucun retard » de « retard non prévisualisable »`

#### Étape 6 : documentation
**Description :** `DESIGN.md` — décrire le contrat du driver de poll (une étape = une requête =
une avance ; réponse validée par son input ; watchdog). Changelog régénéré par `just changelog`.
**Vérification :** `just ci`
**Commit :** `docs: consigner le contrat du driver de poll`

### Décisions techniques

- **`compareBelongsTo` en test unitaire, pas en golden.** Les goldens couvrent les transforms
  de modèle complets (`parseMetadata`, `mergeBehind`, `parseNvdDiff`). Un prédicat booléen suit
  le précédent de `parseCompare` / `parseDefaultBranch` / `upstreamRef`, testés dans
  `tst_model.qml`. Aucun golden n'est touché par ce plan — s'il en bougeait un, ce serait un défaut.
- **Le driver n'est pas golden-testable.** Il vit dans la couche `view` et dépend de `Process` /
  `Quickshell.Io`, hors de portée de `qmltestrunner`. Sa validation est manuelle (`manual_tests.md`)
  et s'appuie sur `just mock`. La partie déterministe est remontée dans `model` (étape 2), c'est
  précisément le but de l'étape 1.
- **`--max-time` 10 s → 20 s.** Un compare GitHub sur un gros dépôt en retard renvoie jusqu'à
  250 commits ; 10 s était atteignable et déclenchait le décalage. 20 s garde une borne franche
  tout en sortant du régime où l'on se coupait soi-même.
- **On garde le séquentiel.** Le bug n'est pas dû à la sérialisation mais à l'absence de lien
  entre une requête et sa réponse. Paralléliser ajouterait le même défaut, en pire.

### Portes de qualité
- [ ] `just ci` passe
- [ ] Aucun golden modifié (aucun n'est censé bouger)
- [ ] Doc synchronisée (même commit)
- [ ] Commits atomiques sur `fix/v0.2.1-poll-driver`
- [ ] `manual_tests.md` exécuté avant clôture
