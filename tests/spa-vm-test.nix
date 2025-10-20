{ pkgs, inputs }:
pkgs.testers.runNixOSTest {
  name = "spa-vm";

  nodes.machine = { pkgs, ... }: {
    imports = [ ../nixos/profiles/spa-machine.nix ];
    _module.args = {
      inherit inputs;
    };

    virtualisation.graphics = false;
    environment.systemPackages = [ pkgs.curlMinimal ];
  };

  testScript = ''
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(80)
    machine.succeed("curl --fail http://127.0.0.1 | grep -q '<div id=\"root\"'")
  '';
}
