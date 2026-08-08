## Plan : Carte DIFF DE CLOSURE (build à la demande)

**Type :** query + modèle + vue + nix + doc
**Objectif :** aperçu avant rebuild — `nvd diff` entre `/run/current-system` et un build
local du toplevel, rendu en carte cockpit.
**Pourquoi :** répondre « la mise à jour est-elle risquée (kernel, taille) ? » sans activer.
**Étage(s) :** `query` | `model` | `view` | `nix` | `doc`

### Périmètre

- **In :** build du toplevel **à la demande** + `nvd diff` → modèle de closure ; carte
  (résumé + console) ; heuristique **REBOOT** ; golden tests du parser.
- **Out :** badges **CVE** (pas de source locale fiable), visionneuse externe, **toute
  mutation** (`nix flake update`, `nixos-rebuild switch`, rollback).

### Invariants (cf. DESIGN.md)

- **Build à la demande sans activation** = observation autorisée. Jamais automatique.
  Activation / génération / rollback restent interdits sans plan dédié.
- `parseNvdDiff` pur et déterministe (golden-testé).
- **nvd = dépendance** (devShell + hm-module + plugin.json).

### Étapes atomiques (branche `feat/v0.2.0-closure-diff`)

1. **DESIGN** — invariant build-sans-activation, spec carte, heuristique REBOOT (CVE reporté).
   `docs: cadre la carte diff de closure`.
2. **query** — `buildToplevel`, `nvdDiff`, `hostnameArgv` + tst_queries. `feat(query): …`.
3. **model** — `closure.js` + fixtures/goldens (`nvd-changes` réel, `nvd-reboot`,
   `nvd-added-removed`, `nvd-empty`) + tst_model. `test(model): …` → `feat(model): …`.
4. **service + nix** — `Closure.qml` ; `nvd` au devShell + hm-module ; `plugin.json`
   (requires + v0.2.0). `feat(view): service build+diff`.
5. **vue** — `ClosureCard.qml`, insertion Cockpit, Settings hostname, câblage widget.
   `feat(view): carte diff de closure`.
6. **doc** — README (état v0.2.0), manual_tests réel, `just changelog`. `chore: doc + changelog`.

### Portes de qualité

- [ ] `just ci` vert ; `just bless` → diff vide
- [ ] Goldens du parser nvd intentionnels
- [ ] nvd déclaré (devShell + hm-module + plugin.json)
- [ ] Doc synchronisée (même commit) ; commits atomiques ; pas de merge/push/tag par Claude
