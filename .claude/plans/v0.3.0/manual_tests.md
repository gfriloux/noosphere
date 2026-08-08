# Tests manuels — v0.3.0 (transport XHR)

Non automatisable : vrai réseau GitHub, `Quickshell.Io`, rendu QML, inspection de processus.

## Préparation

1. `nix develop`
2. `just dev-bar` (instance DMS isolée sur le worktree — cache et réglages séparés du DMS
   quotidien, indispensable pour ne pas perturber la barre en service).
3. Régler le plugin sur une vraie config flake (chemin du flake, token GitHub).
4. Pour les scénarios déterministes : `just mock <scenario>` dans un autre terminal, puis
   endpoint GitHub du plugin sur `http://127.0.0.1:8385`.

Lecture des traces de l'instance dev :
`quickshell log --pid <pid de l'instance dev> -r "*=true"`.

> Rappel : hors tty, Qt route ses logs vers journald. Pour lire `console.log` dans un pipe
> ou un fichier, exporter `QT_LOGGING_TO_CONSOLE=1` — et `QT_LOGGING_RULES` de
> l'environnement vaut `*.debug=false`, à surcharger en `qml=true`.

## §1 — Le transport rend les mêmes résultats qu'avant (étapes 1, 4)

- [ ] `just mock drift` : chaque input affiche le retard **de son propre dépôt** ; croiser
      deux ou trois lignes avec `curl` sur l'API compare.
- [ ] `just mock uptodate` : badge de barre vert, compteur masqué, aucun input en retard.
- [ ] Vrai GitHub (mock arrêté, token réglé) : les retards correspondent à ceux qu'affichait
      la version 0.2.1 sur le même flake — c'est le contrôle de non-régression du plan.
- [ ] Le nombre de lignes correspond au nombre d'inputs directs du `flake.lock` (aucun input
      sauté).
- [ ] Survoler une ligne en retard : la puce « changelog » est présente (`head` résolu).

## §2 — Délai maximal et poll qui ne reste pas bloqué (étape 1)

- [ ] `just mock drift`, puis **tuer le mock en plein poll** : la barre passe en erreur, la
      liste garde le dernier état connu (best-effort, DESIGN inv. 7).
- [ ] Cliquer « check maintenant » après avoir relancé le mock : le poll repart. **Le bouton
      ne doit jamais rester sans effet.**
- [ ] Couper le réseau pendant un poll sur le vrai GitHub : même comportement, retour à la
      normale au rétablissement.
- [ ] Enchaîner cinq clics rapides sur « check maintenant » : un seul poll à la fois, pas de
      doublon de lignes, pas de compteur incohérent.
- [ ] Vérifier dans les traces qu'une requête abandonnée par délai est signalée comme telle
      (« délai dépassé ») et non comme une panne réseau.

## §3 — Les erreurs sont nommées (étape 3)

- [ ] `just mock ratelimit` : la barre passe en erreur avec un message de **limite d'API**,
      et le poll **s'arrête** au lieu de marteler l'API pour chaque input restant.
- [ ] `just mock error` : les inputs concernés passent à « — » (retard indéterminé), l'état
      précédent est conservé.
- [ ] Token volontairement invalide : message de **token refusé** (401), pas un message
      générique.
- [ ] Input pointant un dépôt inexistant (`owner/repo` bidon dans un flake de test) :
      cet input seul reste indéterminé, **les autres continuent d'être comparés**.

## §4 — Le token ne sort plus du processus (étape 1) — motif principal du plan

- [ ] Pendant un poll (cadence forcée ou « check maintenant » en boucle), lancer :
      `pgrep -af curl` → **aucun** processus curl lancé par le plugin.
- [ ] `grep -l "Bearer" /proc/*/cmdline 2>/dev/null` → aucun résultat imputable au plugin.
- [ ] Contrôle de la méthode : refaire les deux commandes avec la version 0.2.1 installée,
      elles doivent **trouver** le token — sinon le test ne prouve rien.
- [ ] Aucun token dans les traces (`quickshell log`), ni dans un message d'erreur affiché.

## §5 — Dépendances (étape 5)

- [ ] Installation via le module HM sur une machine **sans `curl` dans le PATH** du service :
      le plugin fonctionne (dérive affichée, aperçu de closure inchangé).
- [ ] `plugin.json` `requires` ne mentionne plus `curl` ; `nix`, `nvd`, `xdg-open` restent.
- [ ] `grep -rn curl src/` → aucun résultat.

## Non-régression v0.2.x

- [ ] Badge de barre inchangé (état de dérive + pastille compteur).
- [ ] Cartes EN-TÊTE et INPUTS inchangées ; pied cadence + « check maintenant ».
- [ ] Trois états de la carte closure toujours distingués (v0.2.1).
- [ ] Aperçu de closure : build sans activation, `git status` du flake reste propre,
      résumé + console + « recalculer » fonctionnels.
- [ ] `just bless` fonctionne toujours (il utilise XHR sur `file://`, indépendant de ce plan).

## Résultats

_(à remplir lors de la validation)_
