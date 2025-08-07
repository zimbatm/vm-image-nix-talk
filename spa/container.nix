{ pkgs ? import <nixpkgs> { } }:
# see: https://nixos.org/manual/nixpkgs/stable/#javascript-buildNpmPackage
let
  npmPackage = pkgs.buildNpmPackage {
    name = "spa";

    buildInputs = with pkgs; [ nodejs_22 ];

    src = ./.;

    npmDeps = pkgs.importNpmLock { npmRoot = ./.; };

    npmConfigHook = pkgs.importNpmLock.npmConfigHook;

    installPhase = ''
      mkdir $out
      cp -r dist/* $out
    '';
  };
  nginxConfig = pkgs.writeText "nginx.conf" ''
    user nobody nobody;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;
    events {}
    http {
      include ${pkgs.pkgsMusl.nginx}/conf/mime.types;
      access_log /dev/stdout;
      sendfile on;
      server {
        listen 80;
        index index.html;
        location / {
          root ${npmPackage};
        }
      }
    }
  '';
in pkgs.dockerTools.buildLayeredImage {
  name = "spa-nix";
  tag = "latest";
  # see: https://nixos.org/manual/nixpkgs/stable/#sec-fakeNss - provides /etc/passwd & /etc/group...
  contents = [ pkgs.fakeNss ];
  extraCommands = ''
    mkdir -p tmp/nginx_client_body
  '';
  config = {
    Entrypoint = [ "${pkgs.pkgsMusl.nginx}/bin/nginx" "-c" nginxConfig ];
    ExposedPorts = { "80/tcp" = { }; };
  };
}
