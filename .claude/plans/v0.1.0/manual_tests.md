# Tests manuels — v0.1.0

Ce qui n'est pas automatisable (rendu QML, réseau GitHub réel, Quickshell/Wayland).
Enrichi au fil du dev, exécuté en validation.

## Préparation

1. `nix develop`
2. Terminal A : `just mock` — mock du compare GitHub (aucun réseau requis).
3. Terminal B : `just dev-bar` — instance DMS **isolée** chargeant le worktree comme
   plugin « Noosphere (dev) ».
4. Dans cette instance : Settings → Plugins → activer « Noosphere (dev) ».
5. Réglages du plugin : chemin du flake (un flake local réel), owner/repo, branche,
   (optionnel) endpoint du mock, intervalle.

## Cas à vérifier

### Badge de barre
- [ ] **À jour** : tous les inputs à jour → glyphe bleu `#89b4fa`, pastille masquée.
- [ ] **Dérive** : ≥1 input en retard → glyphe jaune `#f9e2af`, pastille = nb d'inputs
      en retard, texte `#1e1e2e`.
- [ ] Le glyphe est bien la rosace/engrenage (8 rayons + moyeu), pas une icône générique.
- [ ] Clic sur le badge → ouvre/ferme le cockpit ancré sous le badge.

### Cockpit — carte EN-TÊTE (liseré `#89b4fa`)
- [ ] Identité « noosphere » + `owner/repo` en mono bleu.
- [ ] Chip branche (icône fork + « main »).
- [ ] Ligne génération + « check amont · il y a … » à droite (temps relatif correct).

### Cockpit — carte INPUTS (liseré `#f9e2af`)
- [ ] En-tête « INPUTS » + « N en retard · M à jour » à droite.
- [ ] Une ligne par input direct : point d'état (jaune si en retard, vert sinon), nom
      mono, chip canal (ex. `unstable`) si présent, âge de lock, texte de retard aligné
      à droite (« N commits en retard » jaune / « à jour » gris).
- [ ] **Hover** d'une ligne en retard : fond de ligne + apparition du lien **changelog**
      (lecture seule) ; pas de bouton « update » (reporté).
- [ ] Clic « changelog » → ouvre `github.com/<owner>/<repo>/compare/<lockRev>...<branch>`
      dans le navigateur par défaut.

### États annexes
- [ ] Pendant un check : le badge conserve la dernière valeur (liste non vidée).
- [ ] **Échec GitHub** (mock scenario `ratelimit`/`error`) : dégradation *silencieuse* —
      les inputs comparés affichent « — » (retard indéterminé), le badge garde sa valeur.
- [ ] **Échec flake** (chemin invalide → `nix` en erreur) : liseré carte INPUTS rouge,
      ligne « échec du check · réessayer », badge en gris.
- [ ] Inputs non-GitHub (ex. `type != github`) : affichés, jamais comparés (« — »).

## Résultats

_(à remplir lors de la validation)_
