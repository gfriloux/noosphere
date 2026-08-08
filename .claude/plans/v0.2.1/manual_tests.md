# Tests manuels — v0.2.1 (driver de poll + état « retard non prévisualisable »)

Non automatisable : `Process`/`Quickshell.Io`, vrai réseau GitHub, rendu QML.

## Préparation

1. `nix develop`
2. `just dev-bar` (instance DMS isolée sur le worktree — cache et réglages séparés du DMS
   quotidien, indispensable pour ne pas perturber la barre en service).
3. Régler le plugin sur une vraie config flake (chemin du flake, token GitHub).
4. Pour les scénarios déterministes : `just mock <scenario>` dans un autre terminal, puis
   endpoint GitHub du plugin sur `http://127.0.0.1:8385`.

Lecture des traces de l'instance dev :
`quickshell log --pid <pid de l'instance dev> -r "*=true"`.

## §1 — Attribution des réponses (étape 3)

- [ ] `just mock drift` : chaque input affiche le retard **de son propre dépôt** ; croiser
      deux ou trois lignes avec `curl` sur l'API compare.
- [ ] `just mock ratelimit` : les inputs concernés passent à « — » (retard indéterminé),
      **aucun** input ne reçoit le retard d'un autre.
- [ ] `just mock error` : idem, l'état précédent est conservé (best-effort, DESIGN inv. 7).
- [ ] Survoler une ligne en retard : la puce « changelog » est présente. Un input en retard
      **sans** puce changelog est le symptôme du bug corrigé — il ne doit plus apparaître.
- [ ] Vérifier qu'un input sauté n'existe plus : le nombre de lignes correspond au nombre
      d'inputs directs du `flake.lock`.

## §2 — Le poll ne reste pas bloqué (étape 4)

- [ ] Couper le réseau pendant un poll (ou `just mock` puis tuer le mock en plein poll) :
      la barre passe en gris (erreur), la liste garde le dernier état connu.
- [ ] Rétablir le réseau, cliquer « check maintenant » : le poll repart. **Le bouton ne doit
      jamais rester sans effet** — c'est la régression visée.
- [ ] Enchaîner cinq clics rapides sur « check maintenant » : un seul poll à la fois, pas de
      doublon de lignes, pas de compteur incohérent.

## §3 — Trois états de la carte closure (étape 5)

- [ ] Flake à jour → `aucun input en retard — rien à prévisualiser`.
- [ ] Flake avec N inputs en retard résolus → bouton `prévisualiser la mise à jour (N)`.
- [ ] Inputs en retard mais amont non résolu (mock renvoyant un compare valide et un
      `GET /repos/…` en erreur, ou un input `git+https` non comparable) →
      `N inputs en retard — amont non résolu, rien à prévisualiser`.
- [ ] Accord singulier : avec un seul input, lire `1 input en retard — …`.
- [ ] La carte ne contredit jamais l'en-tête « X en retard · Y à jour » juste au-dessus.

## Non-régression v0.2.0

- [ ] Badge de barre inchangé (état de dérive + pastille compteur).
- [ ] Cartes EN-TÊTE et INPUTS inchangées ; pied cadence + « check maintenant ».
- [ ] Aperçu de closure : build sans activation, `git status` du flake reste propre,
      résumé + console + « recalculer » fonctionnels.

## Résultats

_(à remplir lors de la validation)_
