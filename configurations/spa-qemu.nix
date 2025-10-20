{ lib, modulesPath, inputs, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
    inputs.self.nixosModules.profile-spa-machine
  ];

  virtualisation.memorySize = 1024;
  virtualisation.forwardPorts = [
    {
      from = "host";
      host.address = "127.0.0.1";
      host.port = 8080;
      guest.port = 80;
    }
  ];
}
