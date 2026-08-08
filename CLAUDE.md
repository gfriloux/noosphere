# CLAUDE.md

Guidage pour Claude Code (claude.ai/code) dans ce dépôt.

> **Avant tout travail sur le code, lire [`DESIGN.md`](./DESIGN.md) puis
> [`PROCEDURE_PLANS.md`](./PROCEDURE_PLANS.md). On ne code pas sans plan validé.**

## Ce qu'est noosphere

Widget de **suivi de dérive de flake NixOS** pour **Quickshell / DankMaterialShell** :
badge d'état dans la barre (état de dérive + compteur d'inputs en retard) + popup cockpit
listant les inputs et leur retard sur l'amont. Compare le `flake.lock` local (via
`nix flake metadata --json`) avec la branche amont sur **GitHub** (API compare), en
**lecture seule** (v1), par polling. Aucune configuration côté serveur. Détails et
invariants : `DESIGN.md`.

## Pile & structure

- **Vue** : QML / Qt Quick (Quickshell), Material 3, Catppuccin Mocha.
- **Données** : couche `query` (argv `nix flake metadata` + URL compare GitHub, purs) →
  service `Noosphere.qml` (exécute Process `nix`, interroge GitHub par `XMLHttpRequest`,
  header `Authorization: Bearer` si token) → `model` (modèle de dérive, pur/testable) →
  `view` (QML). Le QML ne
  **construit** jamais de commande ni d'URL en direct.

```
src/            ← QML Quickshell + couches query/model
tests/          ← fixtures (nix flake metadata + compare GitHub figés) + goldens (modèle attendu)
.claude/plans/  ← plans de version (plan.md, manual_tests.md, phase0_results.md)
tmp/            ← scratch non commité (handoff design, notes)
```

## Dev environment

Toujours entrer le dev shell Nix avant de builder/tester :

```bash
nix develop
```

Pour les commandes non interactives : `nix develop --command just ci`.

## Commandes

```bash
just ci          # porte complète : fmt-check + lint + test
just fmt         # qmlformat -i (formate en place)
just fmt-check   # vérifie le format, échoue si non conforme
just lint        # qmllint, aucun warning toléré
just test        # golden (entrées figées → modèle) + Qt Quick Test
just run         # (à venir) lance le widget dans Quickshell
just bless       # régénère les goldens (relire le diff)
just mock        # mock du compare GitHub (scenario : drift | uptodate | ratelimit | error)
just dev-bar     # instance DMS isolée chargeant le worktree
```

Le `Justfile` est la **seule** définition des gates ; pre-commit et la CI l'appellent.

## Garde-fous (ce qui ne change pas)

- **DESIGN.md fait foi.** Hors invariants → non. Flake local + GitHub source de vérité,
  **lecture seule (v1)**, **l'input est l'unité**, retard mesuré sur l'amont GitHub
  (`ahead_by`), **agnostique au flake** (chemin + owner/repo + branche + token) : invariants
  durs. Passer en écriture (`nix flake update`, `nixos-rebuild`, `rollback`) = décision
  DESIGN explicite + PLAN dédié, pas un ajout discret.
- **Le token GitHub est un secret.** Il vit dans la config / le service `Noosphere.qml`,
  **jamais** dans les couches `query`/`model`, **jamais** dans une fixture ou un golden.
- **Git : hybride.** Claude travaille sur une **branche dédiée**, commite **atomiquement**
  (Conventional Commits, cf. PROCEDURE_PLANS.md §3), et ne fait **jamais** `merge`/`push`/`tag`.
  L'utilisateur relit, merge sur `main`, push.
- **Doc dans le même commit** que le code qu'elle décrit.
- **`tmp/`** : jamais commité.
- **Couche données déterministe** : tout changement de `query`/`model` passe par une
  fixture + un golden (cf. PROCEDURE_PLANS.md §4).
- **Outillage release** (renovate, git-cliff, CI + workflow release) : en place dès v0.1.0.
  Le process de release est dans `README.md` ; le tag reste posé par l'utilisateur.
