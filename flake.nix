{
  description = "How (and why) to build minimal and reproducible Docker images with Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    spa.url = "path:./spa";
    spa.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # Define which systems to support
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Shortcut to generate attributes per system
      eachSystem = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Evaluate a NixOS configuration
      mkNixOS =
        system: modules:
        lib.nixosSystem {
          inherit system modules;
          specialArgs = {
            inherit inputs;
          };
        };

      # Eval all the NixOS configs once
      nixosEvals = lib.genAttrs systems (system: {
        spaAmi = mkNixOS system [ ./configurations/spa-ami.nix ];
        spaHetzner = mkNixOS system [ ./configurations/spa-hetzner.nix ];
        spaVm = mkNixOS system [ ./configurations/spa-qemu.nix ];
      });
    in
    {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            crane
            dive
            hcloud
            jq
            nixos-anywhere
            nixos-rebuild
            nodejs_24
            presenterm
            qemu
            qrencode
            sbomnix
          ];
        };
      });

      packages = eachSystem (
        pkgs:
        let
          amiBuild = nixosEvals.${pkgs.system}.spaAmi.config.system.build;
        in
        {
          spa-ami = amiBuild.amazonImage;

          run-vm = pkgs.writeShellApplication {
            name = "run-spa-vm";
            runtimeInputs = [ pkgs.nixos-rebuild ];
            text = ''
              set -euo pipefail
              nixos-rebuild build-vm --flake ${self}#spa-vm "$@"
              exec result/bin/run-spa-vm-vm
            '';
          };
        }
      );

      checks = eachSystem (pkgs: {
        spa-vm = import ./tests/spa-vm-test.nix {
          inherit pkgs inputs;
        };
      });

      nixosConfigurations = {
        spa-ami = nixosEvals.x86_64-linux.spaAmi;
        spa-hetzner = nixosEvals.x86_64-linux.spaHetzner;
        spa-vm = nixosEvals.x86_64-linux.spaVm;
      };

      nixosModules = {
        profile-spa-machine = import ./nixos/profiles/spa-machine.nix;
        service-spa = import ./nixos/services/spa.nix;
      };
    };
}
