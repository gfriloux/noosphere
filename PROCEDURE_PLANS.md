# PROCEDURE_PLANS.md — Procédure de planification de noosphere

> Ce document définit le processus à suivre **systématiquement** avant tout travail
> sur le code. Chaque changement est décomposé en étapes atomiques, testables et
> commitables isolément.
>
> **Règle fondamentale : on ne code pas sans plan validé.**
> Et : lis [`DESIGN.md`](DESIGN.md) avant tout changement. Si une idée ne s'inscrit
> pas dans les invariants, la réponse est non.

---

## 1. Créer le plan avant tout

Dès qu'une version ou une feature est évoquée, créer :

```
.claude/plans/v{X.Y.Z}/
  plan.md           ← contexte, périmètre, phases, décisions, fichiers touchés
  manual_tests.md   ← tests manuels (enrichis au fil du dev, exécutés en validation)
  phase0_results.md ← état réel du dépôt avant de coder (cf. §2)
```

Les plans vivent **dans `.claude/plans/`**, jamais à la racine. Un plan obsolète est
**supprimé**, pas dupliqué en `_v2`/`_v3`.

### Contenu minimal de `plan.md`

- **Contexte** : d'où on part, pourquoi.
- **Objectif** : ce qu'on veut atteindre.
- **Périmètre** : in scope / out of scope explicites.
- **Étage(s) concerné(s)** : `query` | `model` | `view` | `nix` | `doc`.
- **État du working tree** : ce qui est déjà là, ce qui doit disparaître.
- **Phases / étapes atomiques ordonnées** : chacune avec vérification + message de commit.
- **Décisions techniques** : choix et justifications.

---

## 2. Phase 0 — Audit obligatoire

**Avant de toucher au code**, vérifier l'état réel — ne jamais supposer le dépôt propre :

```bash
nix develop --command just ci
```

Consigner le résultat dans `.claude/plans/v{X.Y.Z}/phase0_results.md`.

---

## 3. Politique git — hybride

- Claude travaille sur une **branche dédiée** (`feat/…`, `fix/…`, `chore/…`,
  `refactor/…`, `docs/…`), jamais directement sur `main`.
- Claude **commite atomiquement** : un changement logique = un commit, en
  [Conventional Commits](#convention-de-commit). Chaque commit passe les portes seul.
- Claude ne fait **jamais** `merge`, `push` ni `tag`. L'utilisateur relit, merge sur
  `main` et push.
- **Un plan se termine toujours par un merge sur `main`.** À la clôture (portes vertes),
  l'utilisateur merge la branche du plan sur `main` et push, **avant** de démarrer le plan
  suivant. On ne laisse pas une branche de plan terminée non mergée : chaque plan part d'un
  `main` à jour.

### Convention de commit

```
type(scope): message court à l'impératif
```

- **type** : `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `ci`.
- **scope** : `query`, `model`, `view`, `nix`, `ui`, ou le module touché.

La doc se met à jour **dans le même commit** que le code qu'elle décrit. Un changement
structurel commité sans MAJ de `DESIGN.md`/`README.md` rend la doc périmée — c'est un défaut.

---

## 4. Discipline de test — golden sur la couche données

La couche `query` + `model` est déterministe : un jeu d'entrées figé (sortie
`nix flake metadata --json` + réponses compare GitHub) produit un modèle exact. On stocke
ce modèle attendu en **fichier de référence** :

```
tests/fixtures/<cas>.json     ← entrée figée (metadata nix / compare GitHub / états à joindre)
tests/golden/<cas>.json       ← modèle de domaine attendu
```

- Un changement de comportement se voit dans le **diff du golden**.
- Un golden qui change par accident = **blocage dur**.
- Régénérer un golden intentionnellement : `just bless`, puis **relire le diff**.
- **Aucun secret dans les fixtures.** Le token GitHub vit dans un header injecté par le
  service ; les entrées figées (compare public) n'en contiennent jamais (cf. DESIGN.md).

**On automatise** : parse de `nix flake metadata` → inputs directs, parse du compare →
`behind`, jointure input↔retard, `behindCount`, `barState`. **On n'automatise pas** : le
rendu QML pixel-perfect, le vrai `nix`/réseau GitHub, le lancement Quickshell sur Wayland.
Ces points partent dans `manual_tests.md`.

---

## 5. Types de changement & recettes

| Type | Étage | Étapes (chacune = 1 commit) |
|---|---|---|
| Nouvelle commande / champ de modèle | `query` `model` | 1. fixture+golden (`test(model): …`) → 2. impl (`feat(query): …`) → 3. doc |
| Nouveau calcul (behind, état) | `model` | 1. fixture+golden → 2. impl (`feat(model): …`) → 3. doc DESIGN si invariant touché |
| Changement de vue / composant | `view` | 1. impl QML (`feat(view): …`) → 2. `manual_tests.md` mis à jour → relecture visuelle |
| Correction de bug | étage concerné | 1. test de régression qui échoue (`test: reproduce …`) → 2. fix (`fix(scope): …`) |
| Refactor | étage concerné | 1. refactor sans changer de golden (`refactor(scope): …`). Si un golden bouge, ce n'était pas un refactor. |
| Doc seule | — | `docs: …` |

---

## 6. Gabarit de plan

```markdown
## Plan : [Titre]

**Type :** [commande | modèle/behind | vue | bug | refactor | doc]
**Objectif :** ...
**Pourquoi :** ...
**Étage(s) :** [query | model | view | nix | doc]

### Fichiers touchés
- [ ] `src/...`
- [ ] `tests/fixtures/...` / `tests/golden/...`
- [ ] `DESIGN.md` / `README.md`

### Étapes atomiques
#### Étape 1 : [Titre]
**Description :** ...
**Vérification :** `just ci` (ou la cible pertinente)
**Commit :** `type(scope): message`

### Portes de qualité
- [ ] `just ci` passe
- [ ] Goldens à jour et intentionnels
- [ ] Doc synchronisée (même commit)
- [ ] Commits atomiques sur une branche dédiée
```

---

## 7. Portes de qualité

Tout changement passe ces portes avant d'être considéré comme terminé. **Une seule
définition** : le `Justfile`. pre-commit et la CI l'appellent.

```bash
just fmt-check   # qmlformat — aucun fichier non formaté
just lint        # qmllint — aucun warning toléré
just test        # golden (entrées figées → modèle) + Qt Quick Test
just ci          # les trois d'affilée
```

---

## 8. Ce qui ne change pas entre les versions

- **DESIGN.md fait foi.** Hors invariants → non.
- **Flake local + GitHub source de vérité, lecture seule (v1), input = unité, retard sur
  l'amont GitHub, agnostique au flake** : invariants durs (cf. DESIGN.md). Passer en écriture
  (`nix flake update`, `nixos-rebuild`, `rollback`) = décision DESIGN explicite, pas un PLAN
  d'impl discret.
- **Le token GitHub est un secret** : jamais dans `query`/`model`, jamais dans une fixture/golden.
- **Git hybride** : branche + commits atomiques par Claude ; merge/push/tag par l'utilisateur.
- **Nix** : toujours `nix develop --command …` pour les commandes non interactives.
- **`tmp/`** : scratch non commité (handoffs design, notes, sorties de travail).
- **Outillage release** (`renovate`, `git-cliff`, CI + workflow release) : en place dès
  v0.1.0 (cf. README.md §Release). Le tag reste posé par l'utilisateur.

---

**Dernière mise à jour :** 2026-08-08
**Statut :** Actif
