# home-manager module: installs noosphere as a DankMaterialShell plugin.
#
# Assembles the plugin (plugin.json + src/ + translations/) in the store and links it into
# DMS's plugin directory. Activation then happens in DMS (Settings → Plugins → Noosphere),
# followed by the settings (flake path, owner/repo, branch, optional GitHub token, interval)
# in that same panel.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.noosphere;

  # translations/ must travel with the plugin: DMS loads the French table from
  # <pluginDir>/translations/<locale>.json by itself, and a plugin directory without it is
  # simply English everywhere, with nothing on screen or in a log saying why.
  plugin = pkgs.runCommandLocal "noosphere-plugin" {} ''
    mkdir -p $out
    cp ${../plugin.json} $out/plugin.json
    cp -r ${../src} $out/src
    cp -r ${../translations} $out/translations
  '';
in {
  options.programs.noosphere.enable =
    lib.mkEnableOption "noosphere — a flake drift tracker widget for DankMaterialShell";

  config = lib.mkIf cfg.enable {
    # DMS discovers the plugin in ~/.config/DankMaterialShell/plugins/.
    xdg.configFile."DankMaterialShell/plugins/Noosphere".source = plugin;

    # Runtime deps: nix (reads the local flake through `nix flake metadata` and builds the
    # toplevel on demand), nvd (the closure diff) and xdg-open (changelog links, provided by
    # xdg-utils). GitHub upstream is queried by the service itself: no external HTTP client
    # is required.
    home.packages = [pkgs.nix pkgs.nvd pkgs.xdg-utils];
  };
}
