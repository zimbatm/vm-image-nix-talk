{ lib, modulesPath, inputs, ... }:
{
  imports = [
    (modulesPath + "/../maintainers/scripts/ec2/amazon-image.nix")
    inputs.self.nixosModules.profile-spa-machine
  ];

  config = {
    image.baseName = "spa-vm";
    # services.amazon-ssm-agent.enable = lib.mkForce false;
    virtualisation.amazon-init.enable = lib.mkForce false;
  };
}
