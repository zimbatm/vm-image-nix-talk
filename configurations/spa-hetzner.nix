{ lib, config, inputs, ... }:

let
  defaultDiskModule =
    { lib, ... }:
    {
      boot.loader.grub.configurationLimit = 3;
      boot.loader.grub.enable = true;
      boot.loader.grub.devices = lib.mkForce [ "/dev/sda" ];

      # Basic Hetzner-friendly layout: BIOS+EFI boot partitions and ext4 root.
      disko.devices.disk.sda = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            grub = {
              label = "grub";
              priority = 1;
              size = "1M";
              type = "EF02";
            };
            ESP = {
              label = "ESP";
              size = "100M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              label = "root";
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
in
{
  imports = [
    defaultDiskModule
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.self.nixosModules.profile-spa-machine
  ];

  networking.hostName = lib.mkDefault "spa-hcloud";

  services.cloud-init.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys = {
    # Talk demo key; replace with your own before provisioning real hosts.
    keys = lib.mkDefault [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
    ];
    keyFiles = lib.mkDefault [ ];
  };

  security.sudo.wheelNeedsPassword = false;
}
