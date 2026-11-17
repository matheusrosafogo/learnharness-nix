{
  description = "LearnHarness para Nix/NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      learnharness = pkgs.callPackage ./package.nix { };
    in
    {
      packages.${system} = {
        default = learnharness;
        learnharness = learnharness;
      };

      # Instalação via módulo NixOS:
      #   imports = [ inputs.learnharness.nixosModules.default ];
      nixosModules.learnharness =
        { pkgs, lib, ... }:
        {
          environment.systemPackages = lib.optional (
            pkgs.stdenv.hostPlatform.system == system
          ) self.packages.${system}.default;
        };

      nixosModules.default = self.nixosModules.learnharness;

      # Permite usar o pacote como `pkgs.learnharness`:
      #   nixpkgs.overlays = [ inputs.learnharness.overlays.default ];
      overlays.default =
        final: prev:
        if final.system == system then
          {
            learnharness = self.packages.${system}.default;
          }
        else
          { };
    };
}
