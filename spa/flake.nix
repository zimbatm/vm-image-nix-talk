{
  description = "An example of a SPA";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        packages = {
          default = pkgs.buildNpmPackage {
            name = "spa-nix";

            buildInputs = with pkgs; [ nodejs_24 ];

            src = self;

            npmDeps = pkgs.importNpmLock { npmRoot = ./.; };

            npmConfigHook = pkgs.importNpmLock.npmConfigHook;

            installPhase = ''
              mkdir $out
              cp -r dist/* $out
            '';
          };

          docker = pkgs.dockerTools.buildLayeredImage {
            name = "spa-nix";
            tag = "latest";

            config = {
              Entrypoint = [
                "${pkgs.pkgsMusl.caddy}/bin/caddy"
                "file-server"
                "--root=${self.packages.${system}.default}"
              ];
              ExposedPorts = { "80/tcp" = { }; };
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ nodejs_24 presenterm crane jq qrencode dive sbomnix ];
        };
      });
}
