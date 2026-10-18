# Changelog

Every notable change to noosphere. Format inspired by [Keep a Changelog], versions in
[SemVer]. Generated from the Conventional Commits by git-cliff.

[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
[SemVer]: https://semver.org/

## [0.4.0] - 2026-10-18

### Bug fixes

- **view**: Keep the error status when a poll verified nothing
- **view**: Clear the 19 findings qmllint reports once imports resolve

### Refactoring

- **model**: Extract the poll driver out of QML and test it

### Documentation

- Translate the changelog scaffolding to English
- Plan the issues pass, and correct the lint measurement
- Apply the branch review fixes
- Make GitHub Issues the only backlog
- Translate DESIGN.md to English
- Correct the README's language, git and version statements
- Replace the house process with the superpowers norm
- Adopt the superpowers document tree and ignore agent scratch
- **plan**: Add backlog entry for translating cliff.toml to English

### Build

- **nix**: Make the lint gate blocking
- **nix**: Resolve QML imports for qmllint through Quickshell's own VFS

### Continuous integration

- Validate plugin.json, and declare that CI does not lint QML

### Miscellaneous

- **deps**: Update softprops/action-gh-release action to v3

## [0.3.0] - 2026-08-08

### Fonctionnalités

- **view** : Nommer la cause d'un échec d'appel GitHub

### Corrections

- **dev** : Rendre les réponses du mock GitHub rattachables à leur input

### Refactorisations

- **view** : Rattacher chaque réponse GitHub par la closure de sa requête
- **view** : Interroger GitHub par XMLHttpRequest au lieu de curl

### Documentation

- Régénère le changelog (v0.3.0)
- **plan** : Consigner les résultats de validation de v0.3.0
- Consigner le transport interne et les pistes ETag / parallélisation
- **plan** : Ouvrir un backlog et y consigner la porte lint défaillante
- **plan** : Planifier le passage de curl à XMLHttpRequest (v0.3.0)

### Tests

- **model** : Couvrir la traduction des erreurs de l'API GitHub

### Divers

- **release** : Passe plugin.json en 0.3.0
- Retirer curl des dépendances runtime
- **deps** : Update cachix/install-nix-action action to v31
- **deps** : Update actions/checkout action to v7

## [0.2.1] - 2026-08-08

### Corrections

- **view** : Distinguer « aucun retard » de « retard non prévisualisable »
- **view** : Garantir la sortie de l'état occupé du poll
- **view** : Attribuer chaque réponse GitHub à l'input qui l'a demandée
- **model** : Rejeter aussi une réponse repo d'un autre input
- **model** : Rejeter une réponse compare qui n'appartient pas à l'input attendu

### Documentation

- Régénère le changelog (v0.2.1)
- Consigner le contrat du driver de poll et l'interdit de se contredire
- **plan** : Planifier v0.2.1 (driver de poll + carte closure honnête)
- **readme** : Passe le README en anglais

### Tests

- **model** : Reproduire l'attribution d'une réponse compare au mauvais input

### Divers

- **release** : Passe plugin.json en 0.2.1

## [0.2.0] - 2026-08-08

### Fonctionnalités

- **view** : Closure = aperçu de mise à jour (sans muter)
- **query** : Override-input pour l'aperçu de mise à jour
- **view** : Carte diff de closure dans le cockpit
- **view** : Service de diff de closure + déclare nvd
- **model** : Parse nvd diff + heuristique de sévérité
- **query** : Build toplevel + nvd diff (diff de closure)

### Corrections

- **view** : Bouton réessayer en erreur + --refresh sur l'aperçu

### Documentation

- Régénère le changelog (aperçu de mise à jour)
- État v0.2.0, structure et changelog
- Cadre la carte diff de closure (build à la demande)

## [0.1.0] - 2026-08-08

### Fonctionnalités

- **view** : Badge rosace + cockpit inputs + réglages
- **view** : Expose le head amont résolu pour le lien changelog
- **view** : Service de dérive (nix flake metadata + compare GitHub)
- **query** : Base d'API GitHub configurable
- **model** : Parse metadata/compare + calcul de dérive
- **query** : Builders nix flake metadata + compare/repo GitHub

### Corrections

- **view** : Retard sur une ligne, popout élargi, liseré inséré
- **view** : Enveloppe le contenu du cockpit dans un Item (popout vide)
- **view** : Dimensionne le popout en amont (cockpit vide au clic)

### Documentation

- Design, invariants et procédure de planification

### Divers

- Dev tooling, release et documentation projet
- **nix** : Socle flake, portes qualité et module home-manager

<!-- généré par git-cliff -->
