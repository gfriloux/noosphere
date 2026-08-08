# Changelog

Toutes les évolutions notables de noosphere. Format inspiré de [Keep a Changelog],
versions en [SemVer]. Généré depuis les Conventional Commits par git-cliff.

[Keep a Changelog]: https://keepachangelog.com/fr/1.1.0/
[SemVer]: https://semver.org/lang/fr/

## [Non publié]

### Fonctionnalités

- **view** : Carte diff de closure dans le cockpit
- **view** : Service de diff de closure + déclare nvd
- **model** : Parse nvd diff + heuristique de sévérité
- **query** : Build toplevel + nvd diff (diff de closure)

### Documentation

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
