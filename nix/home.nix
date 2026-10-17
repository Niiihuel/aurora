# Home Manager module for aurora.
#
#   aurora.shell.enable = true;
#   aurora.shell.devPath = "/home/you/src/aurora/shell";  # optional
#   aurora.hyprland.enable = true;
#   aurora.hyprland.devPath = "/home/you/src/aurora/hypr";   # optional
#
# With a devPath, the files are out-of-store links to the repo, so every save
# is live (the shell hot-reloads; Hyprland reloads its config; compile shaders
# with scripts/shaders.sh). Without one, they come from the store.
{ self, quickshell }:
{ config, lib, pkgs, ... }:
let
  cfg = config.aurora;
  link = devPath: storePath:
    if devPath != null then config.lib.file.mkOutOfStoreSymlink devPath else storePath;
in
{
  options.aurora = {
    shell = {
      enable = lib.mkEnableOption "the aurora Quickshell shell";
      devPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Absolute path to the repo's shell/ directory to link live instead of the store copy.";
      };
    };
    hyprland = {
      enable = lib.mkEnableOption "aurora's Hyprland config";
      devPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Absolute path to the repo's hypr/ directory to link live instead of the store copy.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.shell.enable {
      home.packages = [ quickshell pkgs.inter ];
      xdg.configFile."quickshell/aurora".source = link cfg.shell.devPath
        "${self.packages.${pkgs.stdenv.hostPlatform.system}.aurora-shell}/share/aurora/shell";
    })

    # Only hyprland.lua and its aurora/ folder are linked: ~/.config/hypr stays
    # a plain folder, where aurora writes keybinds.conf and hypridle.conf and
    # this machine may keep a private.lua.
    (lib.mkIf cfg.hyprland.enable {
      xdg.configFile."hypr/hyprland.lua".source = link
        (if cfg.hyprland.devPath != null then "${cfg.hyprland.devPath}/hyprland.lua" else null)
        "${self}/hypr/hyprland.lua";
      xdg.configFile."hypr/aurora".source = link
        (if cfg.hyprland.devPath != null then "${cfg.hyprland.devPath}/aurora" else null)
        "${self}/hypr/aurora";
    })
  ];
}
