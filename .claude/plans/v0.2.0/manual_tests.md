# Tests manuels — v0.2.0 (carte DIFF DE CLOSURE)

Non automatisable : vrai `nix build` + `nvd`, rendu QML, Quickshell/Wayland.

## Préparation

1. `nix develop`
2. `just dev-bar` (instance DMS isolée sur le worktree).
3. Régler le plugin sur une **vraie config flake** (chemin du flake, hostname si
   nixosConfigurations n'est pas keyé sur `hostname`).

## Cas à vérifier

### Carte DIFF DE CLOSURE (liseré pêche/neutre)
- [ ] État initial **idle** : bouton « prévisualiser le rebuild », pas de diff.
- [ ] Clic → **build** : spinner mauve, statut « build… » puis « diff… ».
- [ ] **ready** : ligne résumé « N màj · A ajoutés · R retirés · Δ <taille> » (segments
      colorés), bloc console `#181825` listant `nom  from → to`.
- [ ] Si un paquet kernel/firmware/pilote change : marqueur ▲ + badge **REBOOT** pêche sur
      la ligne, et **liseré de carte pêche** ; sinon liseré neutre `#45475a`.
- [ ] **Erreur** (hostname inexistant, flake non buildable) : liseré rouge, message d'erreur
      (extrait de la sortie nix), pas de crash.
- [ ] Re-cliquer relance un build/diff frais.

### Non-régression v0.1.0
- [ ] Badge de barre inchangé (état de dérive + pastille).
- [ ] Cartes EN-TÊTE et INPUTS inchangées ; pied cadence + « check maintenant ».
- [ ] La carte diff apparaît **entre** INPUTS et le pied ; hauteur du popout ajustée.

## Résultats

_(à remplir lors de la validation)_
