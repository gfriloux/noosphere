# noosphere

Widget de **suivi de dérive de flake NixOS** pour la barre de bureau **Quickshell /
DankMaterialShell**. Un badge d'état dans la barre (état de dérive + compteur d'inputs en
retard) et un popup *cockpit* qui liste les inputs du flake et leur retard sur l'amont.

noosphere compare le `flake.lock` local (`nix flake metadata --json`) avec la branche
amont sur **GitHub** (API compare) — **lecture seule**, par polling. **Rien à installer
côté serveur**, et **aucune mutation** du système : noosphere *observe* la dérive.

Esprit et invariants : [`DESIGN.md`](./DESIGN.md). Méthode de travail :
[`PROCEDURE_PLANS.md`](./PROCEDURE_PLANS.md) et [`CLAUDE.md`](./CLAUDE.md).

## Pile

- **Vue** : QML / Qt Quick (Quickshell), Material 3, Catppuccin Mocha.
- **Données** : `query` (argv `nix flake metadata` + URLs compare GitHub, purs) → service
  `Noosphere.qml` (Process `nix` + `curl`, header `Authorization: Bearer` si token) →
  `model` (dérive, pur/testable) → `view` (QML).
- **Auth** : token GitHub **optionnel** (lève la limite 60 req/h), à portée publique. Il
  vit dans la config/le service, jamais dans les couches données ni les tests.

## État

**v0.1.0 — slice lecture seule.** noosphere est **installable et utilisable** : un service
lit le flake local, interroge l'amont GitHub input par input, et affiche la dérive. Le
**badge de barre** encode l'état (bleu = à jour, jaune + pastille = N inputs en retard,
gris = check en échec), avec un glyphe rosace. Le **popout cockpit** offre une carte
**EN-TÊTE** (identité du flake, branche, génération système courante, dernier check) et une
carte **INPUTS** (une ligne par input direct : point d'état, canal, âge de lock, retard sur
l'amont, lien **changelog** au survol des lignes en retard). Le pied propose la cadence et
un **check maintenant** (re-check, lecture seule).

Reste à venir (mutations = décision DESIGN + plan dédié) : boutons *update* / *tout mettre
à jour*, carte **diff de closure** (`nvd`), carte **rebuild** (timeline + rollback).
Fondations, invariants et direction visuelle : `DESIGN.md`.

## Développement

Toujours entrer le dev shell Nix (fournit quickshell, qmllint/qmlformat/qmltestrunner,
just) :

```bash
nix develop
just ci        # porte complète : fmt-check + lint + test
```

Autres cibles : `just test` (golden + Qt Quick Test), `just fmt` (formate le QML),
`just bless` (régénère les goldens — relire le diff), `just changelog` (régénère
`CHANGELOG.md` via git-cliff). Pour l'essai visuel sans réseau ni serveur :

```bash
just mock       # mock du compare GitHub (drift | uptodate | ratelimit | error)
just dev-bar    # instance DMS isolée chargeant le worktree comme « Noosphere (dev) »
```

Le `Justfile` est la **seule** définition des portes de qualité ; pre-commit et la **CI
GitHub Actions** (`.github/workflows/ci.yml`) l'appellent.

## Structure du code

```
src/query/queries.js         ← builders : argv nix flake metadata + URLs compare/repo GitHub
src/model/inputs.js          ← parse metadata/compare, behind, barState (pur, golden-testé)
src/model/format.js          ← helpers de présentation (relativeAge, stateColor, compareWebUrl)
src/view/Noosphere.qml       ← service : poll nix + compare GitHub → modèle de dérive
src/view/NoosphereWidget.qml ← badge de barre (PluginComponent) + montage du cockpit
src/view/NoosphereGlyph.qml  ← glyphe rosace/engrenage (Canvas)
src/view/Cockpit.qml         ← popout : cartes EN-TÊTE + INPUTS, pied cadence/check
src/view/Settings.qml        ← réglages (chemin flake, dépôt/branche, token, cadence)
tests/                       ← fixtures figées + goldens (modèle attendu)
.claude/plans/               ← plans de version (plan.md, manual_tests.md, phase0_results.md)
```

## Installation

Via home-manager, en tant que plugin DankMaterialShell :

```nix
# flake.nix (inputs)
inputs.noosphere.url = "github:gfriloux/noosphere";

# config home-manager
imports = [inputs.noosphere.homeModules.default];
programs.noosphere.enable = true;
```

Puis, dans DMS : **Settings → Plugins → Noosphere** pour activer le widget, et son panneau
de réglages pour renseigner le chemin du flake, le dépôt/branche affichés et (optionnel) un
token GitHub.

## Configuration

1. **Chemin du flake** : le dossier local contenant `flake.nix` / `flake.lock`
   (ex. `/etc/nixos`).
2. **Dépôt / branche** (affichage) : l'identité du flake montrée dans l'en-tête
   (ex. `gfriloux/nixos`, `main`). Le retard des inputs, lui, se mesure sur *leurs* propres
   branches amont.
3. **Token GitHub** (optionnel) : un token à portée publique lève la limite de 60
   requêtes/h de l'API compare. Il est envoyé par curl en header `Authorization: Bearer`.
4. **Cadence** : la fréquence d'interrogation de l'amont (minutes).

noosphere est **lecture seule** : le token n'a besoin d'aucun droit d'écriture, et rien
n'est jamais écrit sur le flake ni sur le système.

## Release

Versionnage **SemVer**, changelog dérivé des **Conventional Commits** (git-cliff). Le tag
est posé par le **mainteneur** (politique git hybride) et déclenche la publication.

1. Bumper `plugin.json` (`version`) sur la nouvelle version.
2. `just changelog` pour rafraîchir `CHANGELOG.md`, relire le diff, committer.
3. Merger sur `main`, puis :

   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z — <titre>"
   git push origin vX.Y.Z
   ```

Le push du tag déclenche `.github/workflows/release.yml` : git-cliff génère les notes de la
version et une **release GitHub** est créée. Les dépendances (inputs du flake, actions) sont
tenues à jour par **Renovate**.

## Licence

Voir [`LICENSE`](./LICENSE).
