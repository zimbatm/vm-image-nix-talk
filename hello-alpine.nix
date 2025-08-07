{ pkgs ? import <nixpkgs> { } }:
pkgs.dockerTools.buildLayeredImage {
  name = "hello-alpine";
  tag = "latest";
  config.Cmd = "${pkgs.pkgsMusl.hello}/bin/hello";
}
