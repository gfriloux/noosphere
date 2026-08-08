# Tests manuels — v0.2.0 (carte DIFF DE CLOSURE)

Non automatisable : vrai `nix build` + `nvd`, rendu QML, Quickshell/Wayland.

## Préparation

1. `nix develop`
2. `just dev-bar` (instance DMS isolée sur le worktree).
3. Régler le plugin sur une **vraie config flake** (chemin du flake, hostname si
   nixosConfigurations n'est pas keyé sur `hostname`).

## Cas à vérifier

### Carte DIFF DE CLOSURE — aperçu de mise à jour (liseré pêche/neutre)
- [ ] **idle** avec N inputs en retard : bouton « prévisualiser la mise à jour (N) ».
- [ ] **idle** sans dérive : note « aucun input en retard — rien à prévisualiser ».
- [ ] Clic → **build** : spinner mauve, « build de la config mise à jour… » puis « diff… ».
      (Le build pointe les inputs en retard sur leur amont via `--override-input`, sans
      écrire `flake.lock` ni activer — vérifier que `git status` du flake reste propre.)
- [ ] **ready** : résumé « N màj · A ajoutés · R retirés · Δ <taille> » **non nul** (contraste
      avec un build du lock tel quel qui donnerait ~0), console `nom  from → to`.
- [ ] Si nixpkgs en retard fait bouger le kernel : marqueur ▲ + badge **REBOOT** pêche +
      **liseré pêche** ; sinon liseré neutre.
- [ ] **Erreur** (hostname inexistant, éval qui casse) : liseré rouge, message, pas de crash.
- [ ] « recalculer » relance un build/diff frais.

### Non-régression v0.1.0
- [ ] Badge de barre inchangé (état de dérive + pastille).
- [ ] Cartes EN-TÊTE et INPUTS inchangées ; pied cadence + « check maintenant ».
- [ ] La carte diff apparaît **entre** INPUTS et le pied ; hauteur du popout ajustée.

## Résultats

_(à remplir lors de la validation)_
