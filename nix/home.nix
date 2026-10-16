# Home Manager module for the aurora shell.
#
#   aurora.shell.enable = true;
#   aurora.shell.devPath = "/home/nihuel/projects/personal/aurora/shell";  # optional
#
# With devPath set, ~/.config/quickshell/aurora is an out-of-store link to the
# repo, so every save hot-reloads (compile shaders with scripts/shaders.sh).
# Without it, the config comes from the store package with prebuilt shaders.
{ self, quickshell }:
{ config, lib, pkgs, ... }:
let
  cfg = config.aurora.shell;
in
{
  options.aurora.shell = {
    enable = lib.mkEnableOption "the aurora Quickshell shell";
    devPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to the repo's shell/ directory to link live instead of the store copy.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ quickshell pkgs.inter ];
    xdg.configFile."quickshell/aurora".source =
      if cfg.devPath != null
      then config.lib.file.mkOutOfStoreSymlink cfg.devPath
      else "${self.packages.${pkgs.stdenv.hostPlatform.system}.aurora-shell}/share/aurora/shell";
  };
}
