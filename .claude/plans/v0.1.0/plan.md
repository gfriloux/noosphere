## Plan : Bootstrap noosphere — slice lecture seule

**Type :** vue + modèle + query + nix + doc (bootstrap complet)
**Objectif :** premier plugin DMS `noosphere` installable et testé — badge de dérive +
cockpit (EN-TÊTE + INPUTS), en **lecture seule**.
**Pourquoi :** suivre la dérive d'une config NixOS gérée par flake sans quitter la barre.
**Étage(s) :** `query` | `model` | `view` | `nix` | `doc`

### Périmètre

- **In :** `nix flake metadata --json` (local) + GitHub compare (amont) → dérive ;
  badge (uptodate/drift + pastille) ; cockpit cartes EN-TÊTE + INPUTS ; réglages ;
  golden tests couche données ; outillage Nix + release.
- **Out (versions ultérieures) :** toute **mutation** (`nix flake update`, `nixos-rebuild`,
  `rollback`), carte DIFF DE CLOSURE (`nvd`), carte REBUILD (timeline), boutons d'action
  mutants, état `rebuilding` du badge.

### Invariants (cf. DESIGN.md)

- **Lecture seule (v1).** Aucune écriture système. Passer en mutation = décision DESIGN
  explicite + plan dédié.
- Flake local + GitHub = source de vérité. **L'input est l'unité.** Agnostique au flake
  ciblé (chemin/owner/repo/branche en config).
- **Token GitHub = secret** : vit dans le service, jamais dans `query`/`model`, jamais
  dans une fixture/golden.
- Pipeline strict `query → model → view` ; le QML ne construit jamais une requête.

### Étapes atomiques (branche `feat/v0.1.0-bootstrap`)

1. **Socle Nix + portes** — `flake.nix`, `Justfile`, `.gitignore`,
   `.pre-commit-config.yaml`, `nix/hm-module.nix`, `plugin.json`.
   Vérif : `nix develop`, `just --list`. Commit `chore(nix): socle flake + portes`.
2. **Docs fondatrices** — `DESIGN.md`, `CLAUDE.md`, `PROCEDURE_PLANS.md`.
   Commit `docs: design, invariants et procédure`.
3. **query + harness golden** — `src/query/queries.js`, `tests/lib/golden.js`,
   `tests/cases.js`, `tests/tst_golden.qml`, `bless.qml`, fixtures+goldens.
   Vérif : `just test`. Commits `test(query): …` → `feat(query): …`.
4. **model + goldens** — `src/model/inputs.js`, `src/model/format.js`, `tests/tst_model.qml`,
   fixtures+goldens. Vérif : `just ci`. Commits `test(model): …` → `feat(model): …`.
5. **Service** — `src/view/Noosphere.qml`. Commit `feat(view): service de dérive`.
6. **Vue** — `NoosphereGlyph.qml`, `NoosphereWidget.qml`, `Cockpit.qml`, `Settings.qml`.
   Vérif : `just ci` + relecture visuelle. Commit `feat(view): badge + cockpit inputs`.
7. **Dev tooling + release** — `scripts/noosphere-dev`, `scripts/github-mock.py`,
   `README.md`, `CHANGELOG.md`, `cliff.toml`, `renovate.json`, `.github/workflows/*`.
   Commit `chore: dev tooling + release`.

### Portes de qualité

- [ ] `nix develop --command just ci` passe (fmt-check + lint + test)
- [ ] Goldens à jour et intentionnels (`just bless` → diff vide)
- [ ] Doc synchronisée (même commit)
- [ ] Commits atomiques sur `feat/v0.1.0-bootstrap` ; pas de merge/push/tag par Claude
- [ ] Tests manuels (`manual_tests.md`) exécutés sur instance DMS isolée
