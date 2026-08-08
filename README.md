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

**v0.2.0 — dérive + diff de closure.** noosphere est **installable et utilisable**. Le
**badge de barre** encode l'état de dérive (bleu = à jour, jaune + pastille = N inputs en
retard, gris = check en échec), glyphe rosace. Le **popout cockpit** offre :
- une carte **EN-TÊTE** (identité du flake, branche, génération système courante, dernier check) ;
- une carte **INPUTS** (une ligne par input direct : point d'état, canal, âge de lock, retard
  sur l'amont, lien **changelog** au survol des lignes en retard) ;
- une carte **DIFF DE CLOSURE** (v0.2.0) : sur le bouton « prévisualiser le rebuild »,
  noosphere **build le toplevel à la demande** (`nix build`, **sans activation**) et affiche
  le `nvd diff` contre la génération courante — résumé (màj/ajoutés/retirés/Δ taille) +
  console des changements, avec marqueur ▲ / badge **REBOOT** sur les paquets kernel/firmware.

noosphere reste **lecture seule au sens système** : il observe (et build à la demande), il
n'active jamais. Reste à venir (mutations = décision DESIGN + plan dédié) : boutons *update* /
*tout mettre à jour* (`nix flake update`), carte **rebuild** (timeline + rollback). Fondations,
invariants et direction visuelle : `DESIGN.md`.

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
src/query/queries.js         ← builders : nix flake metadata, compare/repo GitHub, nix build, nvd diff
src/model/inputs.js          ← parse metadata/compare, behind, barState (pur, golden-testé)
src/model/closure.js         ← parse nvd diff + heuristique de sévérité (pur, golden-testé)
src/model/format.js          ← helpers de présentation (relativeAge, stateColor, compareWebUrl)
src/view/Noosphere.qml       ← service : poll nix + compare GitHub → modèle de dérive
src/view/Closure.qml         ← service : build toplevel + nvd diff à la demande → modèle de closure
src/view/NoosphereWidget.qml ← badge de barre (PluginComponent) + montage du cockpit
src/view/NoosphereGlyph.qml  ← glyphe rosace/engrenage (Canvas)
src/view/Cockpit.qml         ← popout : cartes EN-TÊTE + INPUTS + DIFF DE CLOSURE, pied
src/view/ClosureCard.qml     ← carte diff de closure (bouton, spinner, résumé, console)
src/view/Settings.qml        ← réglages (chemin flake, hostname, dépôt/branche, token, cadence)
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
5. **Hostname** (optionnel, carte diff de closure) : la clé de `nixosConfigurations` à
   builder pour l'aperçu. Vide → l'hôte courant (`hostname`).

noosphere est **lecture seule au sens système** : le token n'a besoin d'aucun droit
d'écriture, rien n'est jamais écrit sur le flake, et aucun build n'est **activé**. Le seul
effet de bord possible est un `nix build` **à la demande** (bouton « prévisualiser le
rebuild ») qui construit/télécharge des dérivations sans jamais basculer le système. Deps
runtime posées par le module : `nix`, `curl`, `nvd`, `xdg-utils`.

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
