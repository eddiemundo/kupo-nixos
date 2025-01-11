{
  description = "NixOS module for Kupo";
  inputs = {
    haskell-nix.url = github:input-output-hk/haskell.nix;
    nixpkgs.follows = "haskell-nix/nixpkgs";
    iohk-nix.url = github:input-output-hk/iohk-nix;
    flake-utils.url = github:numtide/flake-utils;
    CHaP = {
      url = "github:intersectmbo/cardano-haskell-packages?ref=repo";
      flake = false;
    };
    kupo = {
      url = github:eddiemundo/kupo?ref=release/v2.10;
      flake = false;
    };
  };
  outputs = inputs@{ self, flake-utils, nixpkgs, haskell-nix, iohk-nix, CHaP, kupo, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          inherit (haskell-nix) config; 
          overlays = [
            haskell-nix.overlay
            iohk-nix.overlays.crypto
            iohk-nix.overlays.haskell-nix-crypto
          ];
        };
        project = pkgs.haskell-nix.project' {
          compiler-nix-name = "ghc96";
          projectFileName = "cabal.project";
          src = nixpkgs.lib.cleanSourceWith {
            name = "kupo-src";
            src = "${kupo}";
            filter = path: type:
              builtins.all (x: x) [
                (baseNameOf path != "package.yaml")
              ];
          };
          inputMap = { "https://input-output-hk.github.io/cardano-haskell-packages" = CHaP; };
          modules = [
            { packages.kupo.flags.production = true; }
          ];
        };
      in
        {
          packages = {
            kupo = (project.flake {}).packages."kupo:exe:kupo";
            default = self.packages.${system}.kupo;
          };
          nixos-modules.kupo = { pkgs, lib, ... }: {
            imports = [ ./kupo-nixos-module.nix ];
            services.kupo.package = lib.mkOptionDefault self.packages.${system}.kupo;
          };
        }
    );
}
