{
  description = "aurora — Nihuel's own NixOS desktop: Hyprland + a macOS-style Quickshell shell with liquid glass";

  inputs = {
    # Locked to the same revision as the running system (~/dotfiles) so the
    # shell links the same Qt as the system Quickshell and nothing re-downloads.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    quickshell = {
      url = "github:quickshell-mirror/quickshell/v0.3.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The Hyprland the system runs (~/dotfiles pins the same commit, without
    # follows, so both resolve to the same derivation). Plugins must be built
    # against it exactly or Hyprland refuses to load them.
    hyprland.url = "github:hyprwm/Hyprland/254d6bae775258b554e1d3a4a853f3bc244190d9";
  };

  outputs = { self, nixpkgs, quickshell, hyprland, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      qs = quickshell.packages.${system}.default;
      # Hyprland's own package set: its mkHyprlandPlugin carries that build's headers and ABI hash.
      hpkgs = hyprland.inputs.nixpkgs.legacyPackages.${system}.extend hyprland.overlays.hyprland-packages;
    in
    {
      packages.${system} = {
        # The shell's QML tree with its shaders compiled at build time by the
        # qsb of the same Qt that Quickshell links.
        aurora-shell = pkgs.callPackage ./nix/shell.nix { };
        default = self.packages.${system}.aurora-shell;
        # The login screen (SDDM theme); `.override { language = "es"; }`.
        aurora-login = pkgs.callPackage ./nix/login.nix { };
        # Liquid glass window rims (plugins/rims).
        aurora-rims = hpkgs.callPackage ./plugins/rims { inherit (hpkgs.hyprlandPlugins) mkHyprlandPlugin; };
      };

      # Home Manager module: puts the shell at ~/.config/quickshell/aurora,
      # either from the store or, while developing, as a live link to this repo.
      homeManagerModules.default = import ./nix/home.nix { inherit self; quickshell = qs; };

      checks.${system} = {
        # Every visible string is translated in every language.
        i18n = pkgs.runCommand "aurora-i18n-check" { } ''
          ${pkgs.python3}/bin/python3 ${./scripts/check-i18n.py} ${./shell}
          touch $out
        '';
        # The wallpaper accent picker (shell/core/accent.mjs).
        accent = pkgs.runCommand "aurora-accent-check" { } ''
          ${pkgs.nodejs}/bin/node ${./shell/core}/accent.test.mjs
          touch $out
        '';
        # The launcher's search and calculator (shell/core/search.mjs).
        search = pkgs.runCommand "aurora-search-check" { } ''
          ${pkgs.nodejs}/bin/node ${./shell/core}/search.test.mjs
          touch $out
        '';
        # The screenshot editor's annotation geometry (shell/annotate/geometry.mjs).
        annotate = pkgs.runCommand "aurora-annotate-check" { } ''
          ${pkgs.nodejs}/bin/node ${./shell/annotate}/geometry.test.mjs
          touch $out
        '';
        # Keyboard shortcuts: key presses to Hyprland keys and back (shell/core/keys.mjs).
        keys = pkgs.runCommand "aurora-keys-check" { } ''
          ${pkgs.nodejs}/bin/node ${./shell/core}/keys.test.mjs
          touch $out
        '';
        # The activity extra's /proc parsers (shell/core/activity.mjs).
        activity = pkgs.runCommand "aurora-activity-check" { } ''
          ${pkgs.nodejs}/bin/node ${./shell/core}/activity.test.mjs
          touch $out
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          qs
          pkgs.qt6.qtshadertools # qsb, for scripts/shaders.sh
          pkgs.qt6.qtdeclarative # qmlls (editor LSP) and qmllint
          pkgs.grim
          pkgs.imagemagick
        ];
      };
    };
}
