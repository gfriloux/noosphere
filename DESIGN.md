# DESIGN.md — noosphere

> Ce document définit l'esprit, la structure et les **invariants** de noosphere.
> Avant d'ajouter quoi que ce soit, vérifie que ça s'inscrit ici. Si ce n'est pas
> le cas, la réponse est non.

---

## Ce qu'est noosphere

noosphere est un **widget de suivi de dérive de flake NixOS** pour la barre de bureau
**Quickshell / DankMaterialShell** (Material 3, thème Catppuccin Mocha). Une icône dans
la barre affiche un **badge d'état** (état de dérive + compteur d'inputs en retard) ; au
clic, un **popup cockpit** ancré sous l'icône répond en un regard à : *combien d'inputs
dérivent, et de combien.*

Il compare les **inputs du flake local** (révisions verrouillées dans `flake.lock`, lues
via `nix flake metadata --json`) avec l'**amont** (branche suivie sur GitHub) et affiche
le **retard** (nombre de commits) de chaque input.

La source de vérité est double et **locale à la lecture** : le **flake sur disque** (pour
l'état verrouillé) et l'**API compare de GitHub** (pour l'amont). **Rien n'est à installer
côté serveur.** Le rafraîchissement se fait par **polling** périodique. En v1, noosphere
est en **lecture seule** : il observe la dérive, il ne mute pas le système.

noosphere est une **surface d'observation** au-dessus d'un flake. Ce qu'on fait ensuite
d'une dérive (lire le changelog amont, décider d'un `nix flake update`, lancer un
`nixos-rebuild`) est de la **délégation** ou une **capacité future explicite**, pas le
périmètre v1 : ce document ne détaille pas le rendu des mutations.

Ce n'est **pas** :

- Un gestionnaire de mise à jour. noosphere ne lance **pas** `nix flake update`,
  `nixos-rebuild` ni `rollback` en v1 (cf. invariant *lecture seule*). Il **montre** l'écart.
- Un builder ni un évaluateur de closure. Le diff de closure (`nvd`) et la timeline de
  rebuild sont des **caps futurs** décrits par le handoff design, hors périmètre v1.
- Un miroir de `nix flake update --commit-lock-file`. Il lit le lock, il ne l'écrit pas.

Aujourd'hui un seul flake est configuré, mais rien dans le modèle ne le suppose : voir
l'invariant *agnostique au flake* ci-dessous.

---

## Le pipeline — trois étages

noosphere est une transformation à trois étages. Chaque étage a un contrat clair et est
**indépendamment testable**. Rien ne traverse un étage qui ne devrait pas : la sortie
brute de `nix`/GitHub n'entre pas dans la vue, le QML ne construit jamais de commande ni
d'URL lui-même.

```
  flake local + GitHub                                 popup Quickshell
      │                                                        ▲
      ▼                                                        │
  ┌────────┐        ┌─────────────┐        ┌──────────────────┐
  │ query  │  ───▶  │ model       │  ───▶  │ view             │
  │ (argv/ │        │ (inputs /   │        │ (QML / Material) │
  │  URL)  │        │  dérive)    │        │                  │
  └────────┘        └─────────────┘        └──────────────────┘
```

### 1. `query` — construction des commandes & URLs

Construit l'**argv** de `nix flake metadata --json` et l'**URL** de l'API compare de
GitHub — des fonctions **pures**, **sans aucun secret**. On retourne un **tableau
d'arguments** (jamais une ligne shell : pas d'injection, la requête reste un élément), et
une URL construite à partir de `owner/repo/base/head`. Ne connaît ni le réseau ni la
présentation. L'exécution (Process `nix`, `POST`/`GET` `curl`) est le travail du
**service** (`Noosphere.qml`), pas de cette couche.

> **L'auth vit dans un header, pas dans l'URL.** Le token GitHub (optionnel, pour lever la
> limite de 60 req/h) passe par le header HTTP `Authorization: Bearer <token>`, injecté par
> le service. Conséquence directe : les URLs construites par `query` (et donc les
> **fixtures golden**) ne contiennent jamais de token — committables sans risque.

### 2. `model` — modèle de domaine

Transforme la sortie de `nix flake metadata` et les réponses compare de GitHub en
**modèle de dérive** : la liste des **inputs directs** (nom, canal, révision verrouillée,
date de lock, owner/repo), chacun annoté de son **retard** (`behind` = commits d'écart sur
l'amont). Tient l'état applicatif : `inputs`, `behindCount`, `barState`
(`uptodate | drift`), `connectionStatus`, `lastCheck`. **Pur et testable** : mêmes entrées
→ même modèle (cf. golden tests, PROCEDURE_PLANS.md).

Les helpers de **présentation** (temps relatif « il y a 9 j », couleur d'état, URL web de
comparaison pour le lien changelog) vivent dans `format.js`, **hors du modèle golden**
(dérivables / dépendants de « maintenant »).

### 3. `view` — rendu Quickshell

QML / Qt Quick. Consomme le modèle, ne construit ni n'exécute jamais de commande en
direct. Porte le système visuel ci-dessous, en réutilisant les composants Material 3 de
DankMaterialShell.

### Implémentation

noosphere est un **plugin DankMaterialShell** (`plugin.json` à la racine + `src/`),
installé dans `~/.config/DankMaterialShell/plugins/Noosphere/`. Il hérite du thème
(Catppuccin Mocha) et des composants Material 3 de DMS.

- `query` → `src/query/queries.js` : `flakeMetadata()` (argv nix), `compareApiUrl(...)`
  (URL API GitHub compare), fonctions pures. Exécutées par `src/view/Noosphere.qml`
  (service : Process `nix`, `curl` GET vers l'API GitHub, header `Authorization: Bearer`
  si token, gestion d'erreur/timeout).
- `model` → `src/model/inputs.js` (`parseMetadata` = inputs directs depuis `.locks.nodes`,
  `parseCompare` = `behind` depuis `ahead_by`, `mergeBehind`, `behindCount`, `barState`)
  + `format.js` (`relativeAge`, `stateColor`, `compareWebUrl`) — helpers de présentation
  **hors** du modèle golden. Pur, testé par goldens + inline (`tests/`, `just test` / `just bless`).
- `view` → `src/view/` : `NoosphereWidget` (barre + badge), `NoosphereGlyph` (le glyphe
  rosace/engrenage), `Cockpit` (popout : carte EN-TÊTE + carte INPUTS), `Settings` (config :
  chemin du flake, owner/repo, branche, token optionnel, intervalle). Thème = DMS.

---

## Invariants du domaine

1. **Le flake local + GitHub font foi ; rien côté serveur.** Toute donnée affichée vient
   de `nix flake metadata --json` (état verrouillé) et de l'API compare GitHub (amont). Pas
   de cache parallèle persistant, aucune configuration côté serveur.
2. **Lecture seule (v1).** noosphere lit l'état, il ne le mute pas. `nix flake update`,
   `nixos-rebuild`, `rollback`, l'écriture du `flake.lock` sont **hors périmètre v1** — des
   caps futurs (cf. handoff : carte diff de closure, carte rebuild) qui ne doivent pas être
   peints dans un coin, mais qui ne sont pas construits. Toute mutation sera une décision
   DESIGN explicite + un PLAN dédié.
3. **L'input est l'unité.** Le modèle raisonne en **inputs directs** du flake (ceux
   déclarés à la racine : `.locks.nodes[root].inputs`), pas en nœuds transitifs. Un input =
   un nom, un canal, une révision verrouillée, une date de lock, un retard. Le graphe de
   lock complet est un détail de la couche `query`, pas du domaine.
4. **Le retard se mesure sur l'amont GitHub.** `behind` d'un input = `ahead_by` du compare
   `<lockRev>...<branche amont>` (nombre de commits dont l'amont est en avance sur le lock).
   Seuls les inputs de `type == "github"` sont comparés ; les autres types sont **affichés,
   jamais comparés** (retard indéterminé, jamais compté comme dérive).
5. **Token GitHub optionnel, et secret.** Sans token, l'API publique suffit (limite 60
   req/h). Avec token (header `Authorization: Bearer`), la limite monte. Le token est un
   secret : il vit dans la config/le service, **jamais** dans les couches `query`/`model`
   ni dans les fixtures/goldens.
6. **Agnostique au flake.** noosphere ne modélise pas les flakes comme des entités de
   premier plan : un flake n'est qu'une **facette** (chemin + owner/repo + branche + token).
   Mono ou multi-flake se modélisent sans traitement spécial — une future vue multi-flake
   sera un PLAN si le besoin émerge.
7. **Best-effort sur la connexion.** L'état (`live | polling | error`) est *observé*. Un
   flake introuvable, `nix` lent, GitHub injoignable ou rate-limité **dégrade l'affichage**
   (dernier état connu + statut d'erreur, badge en gris), ne fait **jamais** planter le widget.
8. **Déterminisme de la couche données.** `query` + `model` sont déterministes pour un jeu
   d'entrées figé (sortie `nix flake metadata` + réponses compare) — c'est ce qui rend les
   golden tests possibles. `behind`/`behindCount`/`barState` sont des fonctions pures.

---

## Système visuel

Hérité de DankMaterialShell (Material 3, Catppuccin Mocha) et défini au pixel par le
handoff design (`tmp/design_handoff_noosphere/Noosphere.dc.html`, non commité). Les
**valeurs durables** sont recopiées ci-dessous pour survivre.

> **Fidélité : high (hifi).** Couleurs, tailles, espacements et états sont définitifs.
> Seule liberté : la **police** — police système du shell pour le texte, mono du shell
> (JetBrains Mono / Fira Code) pour tout ce qui est marqué mono.

### Palette — Catppuccin Mocha

| Rôle | Hex |
|---|---|
| Base / fond popup | `#1e1e2e` |
| Mantle / fond console, boutons secondaires | `#181825` |
| Surface0 / cartes | `#313244` |
| Surface1 / bordures | `#45475a` |
| Surface2 / bordure hover | `#585b70` |
| Overlay0 / texte tertiaire | `#6c7086` |
| Subtext0 / texte secondaire | `#a6adc8` |
| Text | `#cdd6f4` |
| **Vert — à jour / succès** | `#a6e3a1` |
| **Jaune — dérive** | `#f9e2af` |
| Pêche — attention / reboot / taille | `#fab387` |
| Rouge — erreur / CVE / danger | `#f38ba8` |
| Mauve — rebuild | `#cba6f7` |
| **Bleu — identité / actions neutres / liens** | `#89b4fa` |
| Bleu hover | `#a6c4fc` / `#b4befe` |

### Mapping couleur des états (impératif)

Le pilier visuel de noosphere. La couleur du **badge de barre** encode l'état de dérive :

| État (`barState`) | Couleur glyphe | Pastille | Sens |
|---|---|---|---|
| `uptodate` | Bleu `#89b4fa` | masquée | tous les inputs à jour |
| `drift` | Jaune `#f9e2af` | fond jaune, chiffre = nb d'inputs en retard | au moins un input dérive |
| `rebuilding` *(cap futur, non atteint en v1)* | Mauve `#cba6f7` | masquée | rebuild en cours |

Dans la carte INPUTS, chaque ligne porte un **point d'état** : jaune `#f9e2af` si en
retard, vert `#a6e3a1` si à jour. Le texte de retard est jaune (« N commits en retard »)
ou gris `#6c7086` (« à jour »).

### Formes & profondeur

- **Badge de barre** : hauteur 28px, rayon 8, fond `#313244`, bord 1px `#45475a`.
- **Popup** : largeur 440px, rayon 18, fond `#1e1e2e`, bord 1px `#313244`, padding 14,
  ombre `0 24px 60px rgba(0,0,0,.55)`, gap entre cartes 11.
- **Cartes** : fond `#313244`, rayon 13, padding 13–15, **liseré gauche 3px** coloré par
  sévérité (`inset 3px 0 0 <couleur>`). Titres de carte : mono 11px/600, letter-spacing
  `.13em`, majuscules, colorés comme le liseré, précédés d'une icône 13px.
- Rayons : 5 (micro-badges) · 7 (mini-boutons) · 8 (lignes, badge, pastille) · 9 (boutons,
  blocs) · 13 (cartes) · 18 (popup) · 20 (chips) · 50 % (points, cercles).
- Typo : **police système** (UI) ; **mono du shell** (noms d'input, révisions, retards,
  chips, titres de carte) ; **Material Symbols** pour les icônes (`sync`, `download`,
  `fork_right`, `schedule`, `settings`, `deployed_code`, `refresh`, `check`, `undo`).

### Animations

- `spin` (rotation, .9s spinner / 3s glyphe) et `pulseGlow` (halo mauve, 1,8s) — **réservés
  à l'état `rebuilding`**, donc **non déclenchés en v1**. Transitions de hover de ligne et
  d'apparition des actions : 120 ms. Aucune autre animation en v1.

### Direction visuelle — cockpit

Un mini-cockpit de dérive. Layout de référence (le prototype HTML détaille le pixel-perfect) :

- **Popup 440px**, colonne de cartes, gap 11.
- **Carte EN-TÊTE** (liseré `#89b4fa`) : glyphe 22px + « noosphere » (16px/700 `#cdd6f4`) et
  `owner/repo` (mono 12px `#89b4fa`) ; à droite, chip branche (icône `fork_right` + nom,
  fond `#1e1e2e`, bord `#45475a`). Ligne 2 : point vert + génération (« n°N · activée il y a
  … ») ; à droite « check amont · il y a … » `#6c7086`.
- **Carte INPUTS** (liseré `#f9e2af`, le cœur du widget) : en-tête « INPUTS » + « N en retard
  · M à jour » à droite. Une ligne par input : point d'état · nom (mono 13px/600) · chip de
  canal optionnel (mono 10,5px `#6c7086`) · « lock <âge> » ; à droite, texte de retard (mono
  11px/600, min-width 104, aligné à droite). **Hover** d'une ligne en retard : fond
  `rgba(255,255,255,.045)` + apparition (120ms) du lien **changelog** (`#89b4fa`, ouvre le
  compare GitHub web) — **lecture seule**.

> **Reporté (hors v1).** Boutons « update » / « Tout mettre à jour », carte **DIFF DE
> CLOSURE** (`nvd`), carte **REBUILD** (timeline update→build→activate→test + rollback), pied
> « check maintenant » mutant. Décrits par le handoff, ils deviendront des PLANs dédiés une
> fois la mutation actée en DESIGN. Le glyphe en rotation (`rebuilding`) n'est pas déclenché.

### États annexes

- **À jour (zen)** : badge bleu, pastille masquée ; carte INPUTS « 0 en retard · M à jour »,
  tous les points verts.
- **Chargement (check en cours)** : colonnes « retard » en placeholder gris `#6c7086`, liste
  **non vidée** (on garde le dernier état connu).
- **Erreur** (flake introuvable, GitHub injoignable/rate-limité) : liseré de la carte INPUTS
  en rouge `#f38ba8`, ligne de statut « échec du check · réessayer », badge de barre en gris
  `#6c7086` gardant la dernière valeur connue.

---

## Clin d'œil Adeptus Mechanicus

Subtil, jamais kitsch. La **noosphère** est le réseau d'information du Mechanicus ; le
glyphe du plugin est une **rosace/engrenage** (roue à 8 rayons + moyeu), rappel discret du
cog mécanique. Vocabulaire sobre (« dérive », « amont », « verrou »). C'est un
assaisonnement, pas un thème.
