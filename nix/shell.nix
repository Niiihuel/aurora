# The aurora shell as a store path: the QML tree from ../shell plus every
# shaders/*.frag compiled to .frag.qsb. Shaders are built here (not committed)
# so they always match the Qt that Quickshell runs on.
{ lib, stdenvNoCC, qt6 }:

stdenvNoCC.mkDerivation {
  pname = "aurora-shell";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [ ../shell ../scripts/shaders.sh ];
  };

  nativeBuildInputs = [ qt6.qtshadertools ];
  # qtshadertools pulls in wrapQtAppsHook; this package is data, not an app.
  dontWrapQtApps = true;

  buildPhase = ''
    runHook preBuild
    patchShebangs scripts/shaders.sh
    QSB=qsb scripts/shaders.sh shell/shaders
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/aurora"
    cp -r shell "$out/share/aurora/shell"
    runHook postInstall
  '';

  meta = {
    description = "aurora's Quickshell configuration";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
