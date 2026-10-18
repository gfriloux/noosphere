{
  description = ''
    noosphere — a NixOS flake drift tracker widget for Quickshell / DankMaterialShell.
    A bar badge (the drift state) plus a cockpit listing the inputs and how far each lags
    behind upstream. Data from `nix flake metadata --json` (local) and GitHub's compare API
    (upstream). Read-only: noosphere observes, it does not mutate the system.
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
        # Launcher for an isolated DMS instance to test the worktree (see scripts/noosphere-dev).
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

            # Runtime du service : lit le flake local (nix) ; nvd calcule le diff de closure
            # (built on demand, see DESIGN.md). curl is no longer a runtime dependency — the
            # service queries GitHub itself — but stays here to cross-check a lag by hand.
            nix
            curl
            nvd

            # Dev: the GitHub compare mock (just mock) + an isolated DMS instance (just dev-bar)
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
            echo "  noosphere — NixOS flake drift tracker for Quickshell / DankMaterialShell"
            echo "  qmllint/qmlformat/qmltestrunner ready."
            echo "  just ci"
            echo ""
          '';
        };
      };
    };
}
