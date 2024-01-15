{
  description = "NixOS module for Kupo";
  #nixConfig = {
  #  extra-experimental-features = [ "nix-command" "flakes" ];
  #  allow-import-from-derivation = "true";
  #  cores = "1";
  #  max-jobs = "auto";
  #  auto-optimise-store = "true";
  #};
  inputs = {
    # should follow inputs in https://github.com/CardanoSolutions/kupo/blob/master/default.nix#L22
    # haskell-nix.url = github:input-output-hk/haskell.nix/974a61451bb1d41b32090eb51efd7ada026d16d9;
    haskell-nix.url = github:input-output-hk/haskell.nix;
    iohk-nix.url = github:input-output-hk/iohk-nix;

    nixpkgs.follows = "haskell-nix/nixpkgs";
    # iohk-nix.inputs.nixpkgs.follows = "haskell-nix/nixpkgs";
    kupo = {
      # 2.7.2
      url = "git+file:///home/jon/projects/kupo?ref=release/v2.7";
      # url = github:CardanoSolutions/kupo;
      flake = false;
    };
    chap = {
      url = "github:intersectmbo/cardano-haskell-packages?ref=repo";
      flake = false;
    };
  };
  outputs = inputs@{ self, nixpkgs, haskell-nix, iohk-nix, chap, ... }:
    let
      perSystem = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
      pkgs = perSystem (system: import nixpkgs { inherit system; overlays =
        [haskell-nix.overlay iohk-nix.overlays.crypto iohk-nix.overlays.haskell-nix-crypto]; inherit (haskell-nix) config; });
      project = perSystem (system: pkgs.${system}.haskell-nix.project {
        compiler-nix-name = "ghc963";
        projectFileName = "cabal.project";
        src = nixpkgs.lib.cleanSourceWith {
          name = "kupo-src";
          src = inputs.kupo;
          filter = path: type:
            builtins.all (x: x) [
              (baseNameOf path != "package.yaml")
            ];
        };
        inputMap = { "https://input-output-hk.github.io/cardano-haskell-packages" = chap; };
      });
      flake = perSystem (system: project.${system}.flake { });
    in
    {
      packages = perSystem (system: {
        kupo = flake.${system}.packages."kupo:exe:kupo";
        default = self.packages.${system}.kupo;
      });
      nixosModules.kupo = { pkgs, lib, ... }: {
        imports = [ ./kupo-nixos-module.nix ];
        services.kupo.package = lib.mkOptionDefault self.packages.${pkgs.system}.kupo;
      };
      herculesCI.ciSystems = [ "x86_64-linux" ];
    };
}
