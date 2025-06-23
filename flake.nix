{
  description =
    "How (and why) to build minimal and reproducible Docker images with Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in with pkgs; {
        devShells.default =
          mkShell { buildInputs = [ nodejs_24 presenterm crane jq qrencode dive sbomnix ]; };
      });
}
