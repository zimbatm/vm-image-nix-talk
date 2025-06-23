{ pkgs ? import <nixpkgs> { } }:
pkgs.dockerTools.buildLayeredImage {
  name = "hello-nix";
  tag = "latest";
  config.Cmd = "${pkgs.hello}/bin/hello";
}
