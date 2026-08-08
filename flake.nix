{
  description = ''
    noosphere — widget de suivi de dérive de flake NixOS pour Quickshell / DankMaterialShell.
    Badge de barre (état de dérive) + cockpit listant les inputs et leur retard sur l'amont.
    Données via `nix flake metadata --json` (local) et l'API compare de GitHub (amont).
    Lecture seule : noosphere observe, il ne mute pas le système.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Module home-manager : installe noosphere comme plugin DankMaterialShell.
      flake.homeModules.default = import ./nix/hm-module.nix;

      perSystem = {pkgs, ...}: let
        # Launcher d'instance DMS isolée pour tester le worktree (cf. scripts/noosphere-dev).
        noosphere-dev = pkgs.writeShellApplication {
          name = "noosphere-dev";
          runtimeInputs = [pkgs.jq];
          text = builtins.readFile ./scripts/noosphere-dev;
        };
      in {
        formatter = pkgs.alejandra;

        packages.dev-bar = noosphere-dev;
        apps.dev-bar = {
          type = "app";
          program = "${noosphere-dev}/bin/noosphere-dev";
        };

        devShells.default = pkgs.mkShell {
          name = "noosphere";
          packages = with pkgs; [
            # Runtime / cible (bless via quickshell, lint/format/test via Qt6)
            quickshell
            qt6.qtdeclarative # qmllint, qmlformat, qmltestrunner
            qt6.qtbase

            # Runtime du service : lit le flake local (nix) + interroge l'amont GitHub (curl) ;
            # nvd calcule le diff de closure (build à la demande, cf. DESIGN.md)
            nix
            curl
            nvd

            # Dev : mock du compare GitHub (just mock) + instance DMS isolée (just dev-bar)
            python3
            jq

            # Outillage projet
            just
            git
            git-cliff # changelog depuis les Conventional Commits (just changelog)

            # Portes Nix (cf. .pre-commit-config.yaml)
            alejandra
            deadnix
          ];

          shellHook = ''
            echo ""
            echo "  noosphere — suivi de dérive de flake NixOS pour Quickshell / DankMaterialShell"
            echo "  qmllint/qmlformat/qmltestrunner prêts."
            echo "  just ci"
            echo ""
          '';
        };
      };
    };
}
