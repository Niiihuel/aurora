# aurora's login screen as an SDDM theme: ../login, plus the shell's glass
# shader compiled for the greeter's Qt and the strings it shows, taken from
# ../shell/i18n (the build fails if one is missing). The greeter can't read
# $HOME, so the wallpaper comes from /var/lib/aurora/login, where the shell
# publishes it (shell/services/Wallpaper.qml).
#
#   aurora-login.override { language = "es"; }
{ lib, stdenvNoCC, qt6, jq, language ? "en" }:

stdenvNoCC.mkDerivation {
  pname = "aurora-login";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [ ../login ../shell/shaders/glass.frag ../shell/i18n ../scripts/shaders.sh ];
  };

  nativeBuildInputs = [ qt6.qtshadertools jq ];
  dontWrapQtApps = true;

  buildPhase = ''
    runHook preBuild
    cp shell/shaders/glass.frag login/
    patchShebangs scripts/shaders.sh
    QSB=qsb scripts/shaders.sh login

    keys='["lock.password", "lock.wrong", "login.sleep", "login.restart", "login.shutDown"]'
    strings=$(jq -n --argjson keys "$keys" '
      reduce inputs as $l ({}; . + { (input_filename | split("/") | last | rtrimstr(".json")):
        ($l | with_entries(select(.key as $k | $keys | index($k)))) })' shell/i18n/*.json)
    echo "$strings" | jq -e --argjson keys "$keys" 'all(.[]; length == ($keys | length))' >/dev/null \
      || { echo "login: a string is missing from shell/i18n" >&2; exit 1; }
    {
      echo '.pragma library'
      echo "var strings = $strings;"
      echo 'function tr(lang, key) { return (strings[lang] || strings.en)[key] || strings.en[key] || key; }'
    } > login/strings.js

    printf '[General]\nbackground=/var/lib/aurora/login/wallpaper.jpg\nlanguage=%s\n' ${lib.escapeShellArg language} > login/theme.conf
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sddm/themes"
    cp -r login "$out/share/sddm/themes/aurora"
    runHook postInstall
  '';

  meta = {
    description = "aurora's login screen (SDDM theme)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
