# Changelog

Toutes les évolutions notables de noosphere. Format inspiré de [Keep a Changelog],
versions en [SemVer]. Généré depuis les Conventional Commits par git-cliff.

[Keep a Changelog]: https://keepachangelog.com/fr/1.1.0/
[SemVer]: https://semver.org/lang/fr/

## [Non publié]

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
