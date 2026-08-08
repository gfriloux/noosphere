# Phase 0 — Audit avant v0.3.0

**Date :** 2026-08-08
**Branche de départ :** `main` @ `2f3a707` (merge PR #2, renovate cachix-install-nix-action)
**Working tree :** propre (`git status --short` vide)

## `nix develop --command just ci`

```
fmt-check : OK (aucun fichier non formaté)
lint      : exit 0 — mais 745 warnings qmllint (cf. réserve ci-dessous)
test      : Totals: 41 passed, 0 failed, 0 skipped, 0 blacklisted, 58ms
EXIT=0
```

Portes vertes, aucun golden en attente, aucun reliquat de v0.2.1.

### Réserve : la porte `lint` ne tient pas sa promesse

`CLAUDE.md` et le `Justfile` annoncent « qmllint, aucun warning toléré ». Mesuré :

| | |
|---|---|
| `just lint` | exit **0** |
| warnings émis | **745** |

Répartition : `Cockpit.qml` 304, `ClosureCard.qml` 230, `Noosphere.qml` 74,
`NoosphereWidget.qml` 66, `Closure.qml` 41, `Settings.qml` 15, `NoosphereGlyph.qml` 9.

Cause racine : `qmllint` est invoqué sans chemin d'import (`-I`) vers les modules
Quickshell, donc il échoue à résoudre `import QtQuick` et `import Quickshell.Io`
(`Failed to import QtQuick. Are your import paths set up properly?`). Tout en cascade :
`Process was not found`, `unresolved-type`, `unqualified`. Et `qmllint` rend malgré tout 0,
donc `just ci` reste vert.

**Conséquence pour ce plan :** le lint ne peut pas signaler une régression dans
`Noosphere.qml`, précisément le fichier réécrit ici. La validation repose donc sur
`just test` (couche `model`, déterministe) et sur `manual_tests.md`.

**Hors périmètre v0.3.0.** Réparer la porte (passer `-I` à `qmllint`, traiter les warnings
comme des erreurs, puis résorber le passif) est un chantier à part entière, avec son propre
plan — il ferait passer 745 warnings de invisibles à bloquants, ce qui n'a rien à voir avec
le remplacement d'un transport HTTP.

## Étude préalable — mesures ayant fondé le plan

Sondes XHR exécutées sous le dev shell (Qt **6.11.1**, quickshell **0.3.0**), contre un
serveur d'écho local et contre `api.github.com`.

| Point vérifié | Résultat mesuré |
|---|---|
| Headers `Accept`, `X-GitHub-Api-Version`, `Authorization: Bearer` | transmis tels quels |
| `User-Agent: noosphere` | **accepté** (non filtré par Qt) ; à défaut Qt envoie `Mozilla/5.0` |
| HTTPS `api.github.com` **sous quickshell** | `status = 200`, `default_branch = master` |
| Statut HTTP réel (403 rate-limit) | `status = 403` + corps JSON lisible |
| Headers de réponse | `X-RateLimit-Remaining`, `Retry-After`, `ETag` accessibles |
| `If-None-Match` → `304` | fonctionne (piste future, hors périmètre) |
| Redirection `301` | **suivie automatiquement** |
| Connexion refusée | `readyState = 4`, `status = 0` |
| `xhr.timeout` / `ontimeout` | **absents** — non implémentés par Qt |
| `xhr.abort()` | fonctionne → `readyState = 4`, `status = 0` |

XHR est par ailleurs **déjà** utilisé dans le dépôt sous quickshell
(`tests/lib/golden.js`, via `just bless`) : le transport n'est pas une nouveauté
d'environnement, seulement un nouvel usage réseau.

### Fuite du token par l'argv — vérifiée sur cette machine

`_ghGet()` place aujourd'hui `-H "Authorization: Bearer <token>"` dans la ligne de commande
de `curl`. Mesuré localement :

```
/proc monté :        proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)   ← pas de hidepid
/proc/<pid>/cmdline : -r--r--r--                                                 ← lisible par tous
```

Tout processus local peut donc lire le token GitHub pendant la durée d'une requête. C'est
le motif principal du plan, et il touche directement le garde-fou « le token est un
secret » de `CLAUDE.md`.
