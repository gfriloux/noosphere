# Module home-manager : installe noosphere comme plugin DankMaterialShell.
#
# Assemble le plugin (plugin.json + src/) dans le store et le lie dans le dossier de
# plugins de DMS. L'activation se fait ensuite dans DMS (Settings → Plugins → Noosphere),
# puis les réglages (chemin du flake, owner/repo, branche, token GitHub optionnel,
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
    lib.mkEnableOption "noosphere — widget de suivi de dérive de flake pour DankMaterialShell";

  config = lib.mkIf cfg.enable {
    # Le plugin est découvert par DMS dans ~/.config/DankMaterialShell/plugins/.
    xdg.configFile."DankMaterialShell/plugins/Noosphere".source = plugin;

    # Deps runtime : nix (lit le flake local via `nix flake metadata` et build le toplevel
    # à la demande), nvd (diff de closure) et xdg-open (liens changelog, fourni par
    # xdg-utils). L'amont GitHub est interrogé par le service lui-même : aucun client HTTP
    # externe n'est requis.
    home.packages = [pkgs.nix pkgs.nvd pkgs.xdg-utils];
  };
}
