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
  };

  outputs = { self, nixpkgs, quickshell, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      qs = quickshell.packages.${system}.default;
    in
    {
      packages.${system} = {
        # The shell's QML tree with its shaders compiled at build time by the
        # qsb of the same Qt that Quickshell links.
        aurora-shell = pkgs.callPackage ./nix/shell.nix { };
        default = self.packages.${system}.aurora-shell;
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
