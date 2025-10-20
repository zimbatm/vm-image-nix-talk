{
  pkgs,
  modulesPath,
  lib,
  inputs,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
    ../services/spa.nix
  ];

  # comment this to break on perl dependencies
  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  networking.hostName = "spa-vm";
  time.timeZone = "UTC";

  services.spa-app = {
    enable = true;
    package = inputs.spa.packages.${pkgs.system}.default;
    host = "spa.local";
    port = 80;
  };

  users.users.root = {
    # INSECURE, used for demo
    initialPassword = "demo1234";
    hashedPasswordFile = lib.mkForce null;
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  environment.systemPackages = [ ];

  system.stateVersion = "25.05";
}
