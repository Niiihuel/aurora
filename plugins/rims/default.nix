# The rims plugin. mkHyprlandPlugin builds it against the Hyprland it comes
# from (headers + ABI hash), so the flake calls this with the package set of
# the exact Hyprland the system runs; any other one refuses to load it.
{ mkHyprlandPlugin, lib, cmake, pkg-config }:

mkHyprlandPlugin {
  pluginName = "aurora-rims";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ cmake pkg-config ];

  meta = {
    description = "Liquid glass rims on every window for aurora";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
