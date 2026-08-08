# Phase 0 — Audit (v0.2.0)

**Date :** 2026-08-08
**Branche :** `feat/v0.2.0-closure-diff` (partie de `main` post-merge v0.1.0)

## État réel

- `main` porte le merge v0.1.0 (`0b76fb3`) et le tag `v0.1.0`. Release GitHub OK, install
  home-manager validée.
- `nix develop --command just ci` : **vert** (fmt-check + lint + 27 tests) avant de coder.

## Baseline technique — format `nvd diff` (capturé en réel)

`nvd diff /nix/var/nix/profiles/system-423-link system-424-link` :

```
<<< /nix/var/nix/profiles/system-423-link
>>> /nix/var/nix/profiles/system-424-link
Version changes:
[C*]  #1  curl       8.20.0 x3, … -> 8.20.0 x3, …
Added packages:
[A.]  #1  noosphere-plugin  <none>
Closure size: 2900 -> 2904 (17 paths added, 13 paths removed, delta +4, disk usage +142.7KiB).
```

Conséquences parser (`parseNvdDiff`) :
- Sections : `Version changes:` / `Added packages:` / `Removed packages:`.
- Ligne d'entrée : `[<flags>]  #<n>  <nom>  <valeur>`. Changes → `<valeur>` contient ` -> `
  (from → to). Added/Removed → version seule (`<none>` possible).
- Ligne `Closure size: A -> B (… delta ±N …, disk usage ±X).` → sizeDelta + paths.

Les générations locales n'ont pas de changement kernel : le cas REBOOT sera une fixture
**synthétique** au même format (kernel `linux` → sévérité reboot).

## Décision

v0.2.0 = carte **DIFF DE CLOSURE**, **build à la demande** (jamais automatique, sans
activation). `nvd` déclaré en dépendance (devShell + hm-module + plugin.json). Confirmé
avec l'utilisateur.
