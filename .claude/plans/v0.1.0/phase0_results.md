# Phase 0 — Audit (v0.1.0)

**Date :** 2026-08-08
**Branche :** `feat/v0.1.0-bootstrap`

## État réel du dépôt avant de coder

- Dépôt quasi vierge : seul `LICENSE` est commité (commit initial `5b0c151`).
- `tmp/design_handoff_noosphere/` présent mais **non commité** (handoff design ; reste
  dans `tmp/`, jamais versionné — invariant repris de auspex).
- **Pas de `flake.nix`** → `nix develop --command just ci` **non exécutable** en l'état.
  La porte `just ci` deviendra exécutable dès la Phase 1 (socle Nix) puis verte à partir
  de la Phase 3 (premiers tests golden).

## Baseline technique confirmée

`nix flake metadata --json` (exécuté sur `../auspex`) fournit la structure source :

```
.locks.root                = "root"
.locks.nodes[<name>].locked   = { type, owner, repo, rev, lastModified, ref? }
.locks.nodes[<name>].original = { type, owner, repo, ref? }
.locks.nodes["root"].inputs   = { <name>: <nodeKey|[nodeKey]> }   // inputs DIRECTS
.description, .path, .resolvedUrl, .url (rev + ref courants)
```

Conséquences pour le `model` :
- On ne garde que les **inputs directs** (parcours de `nodes[root].inputs`), pas le
  transitif.
- `channel` = `original.ref` (ex. `nixos-unstable`) quand présent, sinon absent.
- `lockRev` = `locked.rev`, `lockedAt` = `locked.lastModified`, `owner`/`repoName` =
  `locked.owner`/`locked.repo`. On ne traite que `type == "github"` pour le compare
  amont (autres types : affichés, jamais comparés).

## Décision

Périmètre v0.1.0 = slice **lecture seule** (badge + EN-TÊTE + INPUTS), aucune mutation
système. Confirmé avec l'utilisateur.
