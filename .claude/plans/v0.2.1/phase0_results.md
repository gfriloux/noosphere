# Phase 0 — Audit avant v0.2.1

**Date :** 2026-08-08
**Branche de départ :** `main` @ `2d19363` (merge `docs/readme-english`)
**Working tree :** propre (`git status --short` vide)

## `nix develop --command just ci`

```
fmt-check : OK (aucun fichier non formaté)
lint      : OK (qmllint sans warning)
test      : Totals: 36 passed, 0 failed, 0 skipped, 0 blacklisted, 55ms
EXIT=0
```

Portes vertes avant de coder. Aucun golden en attente, aucun reliquat de v0.2.0.

## Investigation préalable (contexte du plan)

Le bug rapporté (un input à 11 commits de retard, carte closure affichant
« aucun input en retard ») **n'est pas reproductible** après coup : l'état a disparu
au cours de la session. Ce qui a été mesuré :

| Environnement | `closureOverrides` | `Closure.overrides` | `updateCount` |
|---|---|---|---|
| quickshell headless, vrai flake + vrai token | 2 | 2 | 2 |
| instance DMS isolée (`just dev-bar`) | 2 | 2 | 2 |
| instance DMS réelle de l'utilisateur | 2 | 2 | 2 |

Le plugin installé est byte-identique au worktree (`diff -r` sur les trois révisions
présentes dans le store). La chaîne de liaison se réévalue correctement, y compris
lorsque le popout préexiste au premier poll.

**Conclusion :** l'état fautif était transitoire, côté service. Le diagnostic a en
revanche mis au jour un défaut **reproduit** du driver séquentiel de poll (cf. `plan.md`),
qui produit exactement cette classe de symptôme.
