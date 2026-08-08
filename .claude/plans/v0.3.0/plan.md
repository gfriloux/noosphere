## Plan : v0.3.0 — remplacer curl par XMLHttpRequest pour les appels GitHub

**Type :** refactor (transport) + fix (fuite de secret)
**Objectif :** que les appels à l'API GitHub partent du processus lui-même, sans passer par
un `curl` externe : le token cesse d'être exposé dans l'argv, le statut HTTP redevient
exploitable, et le rattachement d'une réponse à sa requête devient structurel.
**Pourquoi :** le token GitHub est aujourd'hui lisible par tout processus local via
`/proc/<pid>/cmdline` pendant chaque requête (mesuré, cf. `phase0_results.md`), et `curl -s`
avale le statut HTTP — un 403 rate-limit est indiscernable d'une réponse vide.
**Étage(s) :** `model`, `view`, `nix`, `doc`
**Version :** 0.3.0 — mineure : les dépendances runtime changent (`curl` disparaît) et les
messages d'erreur deviennent explicites. Aucune rupture de configuration.

### Contexte

`src/view/Noosphere.qml` interroge GitHub via deux `Process` réutilisés (`repoProc`,
`cmpProc`) exécutant `curl`, dont l'argv est construit par `_ghGet()` (l.107-116). Quatre
défauts, tous liés au transport :

1. **Le token fuit par l'argv.** `-H "Authorization: Bearer <token>"` est un argument de
   `curl`. Sur cette machine `/proc` est monté sans `hidepid` et `/proc/<pid>/cmdline` est
   en `-r--r--r--` : n'importe quel processus local lit le token pendant la requête. C'est
   une violation directe du garde-fou « le token est un secret » (`CLAUDE.md`).
2. **Le statut HTTP est perdu.** `curl -s` rend le corps, pas le code. Un 403 rate-limit
   renvoie `{"message": "API rate limit exceeded"}`, qui échoue silencieusement à
   `compareBelongsTo` : l'input reste en retard indéterminé, sans qu'on sache pourquoi.
   Le scénario `ratelimit` de `scripts/github-mock.py` existe déjà, mais l'IHM ne peut
   rien en dire.
3. **Les redirections ne sont pas suivies.** `curl -s` sans `-L` : un dépôt renommé
   (301 sur `/repos/…`) casse en silence.
4. **Le rattachement réponse → requête est artisanal.** `_current` / `_await`
   (l.43-58) existent parce que deux `Process` uniques sont réutilisés pour N inputs —
   c'est ce qui a motivé le correctif v0.2.1. Avec un objet XHR par requête, la réponse est
   rattachée par sa closure : la classe de bug disparaît au lieu d'être gardée.

Mesures d'aptitude sous Qt 6.11.1 / quickshell 0.3.0 : cf. `phase0_results.md`. Retenir
que le seul manque est `xhr.timeout` / `ontimeout`, absents — `abort()` fonctionne, donc le
délai maximal se réimplémente avec un `Timer` par requête.

### Périmètre

**In scope**
- Helper HTTP XHR dans le service `Noosphere.qml`, en remplacement de `_ghGet()` argv+`curl`.
- Délai maximal par requête (`Timer` + `abort()`), en remplacement de `--max-time 20`.
- Traduction pure du statut HTTP en message d'erreur (`model`), et son usage par le service.
- Simplification du driver : rattachement par closure, retrait de `_await` / `_current`.
- Retrait de `curl` des dépendances runtime (`plugin.json`, `nix/hm-module.nix`, `README.md`).
- Documentation (`DESIGN.md`, `CLAUDE.md`, `README.md`) dans les mêmes commits que le code.

**Out of scope**
- **Paralléliser les appels GitHub.** Le séquentiel reste volontaire (budget de requêtes,
  simplicité, précédent v0.2.1). XHR le rend possible ; ce plan ne le fait pas. Le gain
  serait la latence d'un poll (~15 requêtes), le coût un contrôle de concurrence et un
  timer par requête en vol. → TODO futur, plan dédié.
- **Requêtes conditionnelles `If-None-Match` / `ETag`.** Vérifiées fonctionnelles (304 reçu).
  Le gain est réel — un poll horaire sur un flake stable ne consommerait presque plus de
  quota, ce qui compte surtout **sans** token (60 req/h contre ~15 requêtes par poll). Le
  coût est un cache mémoire des ETags dans le service, donc un état supplémentaire à
  invalider. → TODO futur, plan dédié.
- Toute écriture (`nix flake update`, `nixos-rebuild`, rollback) — invariant DESIGN.
- Réparation de la porte `lint` (745 warnings invisibles, cf. `phase0_results.md`) —
  chantier distinct, plan dédié.
- Le transport de `nix` / `nvd` / `hostname` : ce sont des processus, ils restent des
  `Process`. Seul l'HTTP change.

### État du working tree

Propre, `main` @ `2f3a707`, portes vertes (41 tests). Rien à faire disparaître.

### Fichiers touchés

- [ ] `src/view/Noosphere.qml` — helper XHR, délai par requête, driver
- [ ] `src/model/inputs.js` — `githubErrorMessage()` (pure)
- [ ] `tests/tst_model.qml` — couverture de `githubErrorMessage`
- [ ] `plugin.json` — `requires` sans `curl`, puis version 0.3.0
- [ ] `nix/hm-module.nix` — `home.packages` sans `pkgs.curl`
- [ ] `flake.nix` — commentaire du dev shell (curl y reste, outil de diagnostic)
- [ ] `DESIGN.md` — étage `query`/service : transport HTTP, pistes écartées
- [ ] `CLAUDE.md` — ligne 21 (pile & structure)
- [ ] `README.md` — l.22, 112, 121 (architecture, token, dépendances)
- [ ] `.claude/plans/v0.3.0/manual_tests.md`
- [ ] `CHANGELOG.md` — régénéré (`just changelog`)

### Étapes atomiques

#### Étape 1 : le transport passe en XHR
**Description :** dans `src/view/Noosphere.qml`, remplacer `_ghGet(url)` (argv curl) par
`_ghGet(url, onDone)` :
- un objet `XMLHttpRequest` **par requête**, asynchrone (jamais `open(..., false)` : le
  plugin vit dans le processus DMS, un appel synchrone gèlerait la barre) ;
- headers identiques à aujourd'hui (`Accept`, `X-GitHub-Api-Version`, `User-Agent`, et
  `Authorization: Bearer` si token) — vérifiés transmis tels quels par Qt ;
- délai maximal de 20 s par requête via un `Timer` dédié + `abort()`, en remplacement de
  `--max-time 20` ; le drapeau « abandonné par nous » est porté par la closure, pour
  distinguer un abandon d'une erreur réseau (les deux rendent `status = 0`) ;
- `repoProc` et `cmpProc` supprimés ; `repoProc.onExited` / `cmpProc.onExited` avec eux.
`_await` / `_current` sont **conservés tels quels** à cette étape : on change le transport,
rien d'autre. Doc `DESIGN.md` (l.70, l.105) et `CLAUDE.md` (l.21) dans le même commit.
**Vérification :** `just ci` + `manual_tests.md` §1 et §2
**Commit :** `refactor(view): interroger GitHub par XMLHttpRequest au lieu de curl`

#### Étape 2 : test de la traduction d'une erreur d'API
**Description :** ajouter dans `tests/tst_model.qml` la couverture de
`githubErrorMessage(status, body, aborted)` : chaîne vide si 2xx ; message dédié pour 401
(token refusé), 403/429 rate-limit (distingué d'un 403 ordinaire par le corps), 404
(dépôt introuvable), 5xx (GitHub indisponible), `status = 0` avec et sans `aborted`
(délai dépassé / réseau injoignable). Le test échoue (fonction absente).
**Vérification :** `just test` échoue sur `test_githubErrorMessage*`
**Commit :** `test(model): couvrir la traduction des erreurs de l'API GitHub`

#### Étape 3 : les erreurs GitHub deviennent lisibles
**Description :** implémenter `githubErrorMessage()` dans `src/model/inputs.js` (pure,
documentée comme ses voisines) et l'utiliser dans le service. Règle d'usage, explicite :

| Cas | Conduite |
|---|---|
| 401, 403 rate-limit, 429 | `_fail(message)` — la cause vaut pour toutes les requêtes suivantes, inutile de marteler l'API ; dernier état conservé (inv. 7) |
| 404, 5xx, réseau, délai dépassé | input laissé en retard indéterminé, on avance |

**Vérification :** `just ci` + `manual_tests.md` §3
**Commit :** `feat(view): nommer la cause d'un échec d'appel GitHub`

#### Étape 4 : le driver n'a plus besoin de garde-fou
**Description :** une fois le transport validé, retirer `_await` et `_current` : chaque
réponse est rattachée à son input par la closure de sa requête, et une requête ne peut
aboutir qu'une fois (plus de double signal `onExited` + `onStreamFinished`). Le watchdog
d'étape devient le timer de requête ; le watchdog global ne couvre plus que l'étape `nix`.
`compareBelongsTo` / `repoBelongsTo` sont **conservés** : ils valident le contenu, pas le
rattachement, et restent utiles face à une réponse d'erreur bien formée.
**Vérification :** `just ci` + `manual_tests.md` §1, §2, §4
**Commit :** `refactor(view): rattacher chaque réponse GitHub par la closure de sa requête`

#### Étape 5 : curl sort des dépendances runtime
**Description :** `plugin.json` (`requires` : `nix`, `nvd`, `xdg-open`),
`nix/hm-module.nix` (`home.packages` sans `pkgs.curl`, commentaire l.29 ajusté),
`README.md` (l.121). `curl` **reste dans le dev shell** (`flake.nix`) : il sert au
diagnostic manuel (croiser un retard avec l'API), son commentaire est reformulé.
**Vérification :** `just ci` + installation propre via le module HM (`manual_tests.md` §5)
**Commit :** `chore: retirer curl des dépendances runtime`

#### Étape 6 : consigner les pistes écartées
**Description :** `DESIGN.md` — noter, à l'étage service, que le transport HTTP est interne
au processus (et pourquoi : le secret ne doit pas transiter par un argv), puis les deux
capacités désormais **atteignables mais non prises** : requêtes conditionnelles `ETag`
(économie de quota, surtout sans token) et parallélisation des compare (latence de poll).
Chacune reste un plan dédié, à l'image des autres caps futurs du document.
**Vérification :** `just ci`
**Commit :** `docs: consigner le transport interne et les pistes ETag / parallélisation`

#### Étape 7 : release
**Description :** `plugin.json` en 0.3.0, changelog régénéré (`just changelog`).
**Vérification :** `just ci`
**Commit :** `chore(release): passe plugin.json en 0.3.0`

### Décisions techniques

- **Un XHR par requête, pas un objet réutilisé.** C'est le cœur du gain : réutiliser un
  objet reproduirait exactement le défaut d'attribution corrigé en v0.2.1.
- **Le délai maximal est maison.** Qt n'implémente ni `xhr.timeout` ni `ontimeout`
  (vérifié) ; `abort()` fonctionne (`readyState = 4`, `status = 0`). D'où `Timer` + `abort()`,
  et un drapeau de closure pour distinguer l'abandon volontaire de l'échec réseau, les deux
  rendant `status = 0`.
- **20 s conservés.** Même borne qu'aujourd'hui (portée de 10 à 20 s en v0.2.1 pour les gros
  compare) : on remplace un transport, on ne rejoue pas ce réglage.
- **Le séquentiel est conservé.** Cf. hors périmètre : la correction v0.2.1 a montré que le
  problème n'était pas la sérialisation. On ne change qu'une chose à la fois.
- **`githubErrorMessage` en test unitaire, pas en golden.** Précédent direct :
  `compareBelongsTo` / `repoBelongsTo` / `parseCompare` sont couverts dans `tst_model.qml`.
  Aucun golden ne doit bouger dans ce plan — s'il en bougeait un, ce serait un défaut.
- **La couche `query` n'est pas touchée.** Elle ne produit que des URLs
  (`compareApiUrl`, `repoApiUrl`) ; le transport a toujours appartenu au service. C'est ce
  qui rend ce plan possible sans toucher fixtures ni goldens, et `tst_queries.qml` reste
  intact.
- **Les redirections sont suivies par Qt** (301 vérifié) : c'est un gain, un dépôt renommé
  cessera de casser en silence. Nuance retenue : Qt réémet `Authorization` sur la cible de
  la redirection. Sans conséquence sur `api.github.com` ; à garder en tête si `apiBase`
  pointe ailleurs qu'un mock local.
- **`just mock` continue de fonctionner** : HTTP local vérifié sous quickshell, `apiBase`
  reste le point de bascule.

### Portes de qualité
- [ ] `just ci` passe à chaque étape
- [ ] Aucun golden modifié (aucun n'est censé bouger)
- [ ] `tests/tst_queries.qml` inchangé
- [ ] Aucune occurrence de `curl` dans `src/`
- [ ] Le token n'apparaît dans l'argv d'aucun processus pendant un poll (`manual_tests.md` §4)
- [ ] Doc synchronisée (même commit que le code)
- [ ] Commits atomiques sur `refactor/v0.3.0-xhr-transport`
- [ ] `manual_tests.md` exécuté avant clôture
