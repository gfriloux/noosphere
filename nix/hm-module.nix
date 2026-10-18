# Module home-manager : installe noosphere comme plugin DankMaterialShell.
#
# Assemble le plugin (plugin.json + src/) dans le store et le lie dans le dossier de
# plugins de DMS. L'activation se fait ensuite dans DMS (Settings → Plugins → Noosphere),
# then the settings (flake path, owner/repo, branch, optional GitHub token,
# intervalle) dans ce panneau.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.noosphere;

  plugin = pkgs.runCommandLocal "noosphere-plugin" {} ''
    mkdir -p $out
    cp ${../plugin.json} $out/plugin.json
    cp -r ${../src} $out/src
  '';
in {
  options.programs.noosphere.enable =
    lib.mkEnableOption "noosphere — a flake drift tracker widget for DankMaterialShell";

  config = lib.mkIf cfg.enable {
    # DMS discovers the plugin in ~/.config/DankMaterialShell/plugins/.
    xdg.configFile."DankMaterialShell/plugins/Noosphere".source = plugin;

    # Deps runtime : nix (lit le flake local via `nix flake metadata` et build le toplevel
    # on demand), nvd (the closure diff) and xdg-open (changelog links, provided by
    # xdg-utils). GitHub upstream is queried by the service itself: no HTTP client
    # externe n'est requis.
    home.packages = [pkgs.nix pkgs.nvd pkgs.xdg-utils];
  };
}
