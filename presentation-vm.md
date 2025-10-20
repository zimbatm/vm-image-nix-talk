---
title: "Distributing apps on VMs and bare metal with NixOS"
sub_title: "Nix Bern, 26.06.2025"
author: "Jonas Chevalier"
---

# About your host

Jonas Chevalier (aka zimbatm).

I like to build things.

![numtide logo](numtide-logo.png)

Nix and NixOS consulting since 2016.

direnv, treefmt, nixpkgs-fmt, NixCon,

<https://numtide.com>

<!-- end_slide -->

# Why a Second Story?

B2B.

- Containers are great.
- What if you need a VM or deploy on bare metal?
- Show you the NixOS module system.
- Show you how Nix makes software composable.

<!-- end_slide -->

# Agenda

1. Quick recap of where we were
2. Declaring a NixOS service module
3. Declaring a full NixOS system
4. Local VM demo
5. Test your service with NixOS tests
6. Building a cloud image (AMI and friends)
7. Checking the system closure
8. Deploy existing hardware with NixOS-anywhere
9. Known issues and downsides

<!-- end_slide -->

# Quick Recap

- How to package apps with Nix (`spa/flake.nix`)
- How to build a minimal docker (`spa/flake.nix`)

<!-- end_slide -->

# Declaring the Service Module

```nix
# nixos/services/spa.nix
{ lib, config, ... }:
let
  cfg = config.services.spa-app;
  inherit (lib) mkEnableOption mkIf mkOption types;
in {
  options.services.spa-app = {
    enable = mkEnableOption "serving the SPA with nginx";
    package = mkOption {
      type = types.package;
      description = "Derivation containing the SPA static assets.";
    };
    host = mkOption { type = types.str; default = "spa.local"; };
    port = mkOption { type = types.int; default = 80; };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      virtualHosts."${cfg.host}" = {
        default = true;
        root = cfg.package;
        listen = [{ addr = "0.0.0.0"; port = cfg.port; }];
        locations."/" = { tryFiles = "$uri $uri/ /index.html"; };
      };
    };
  };
}
```

<!-- end_slide -->

# Declaring a Full NixOS System

```nix
# nixos/profiles/spa-machine.nix
{ pkgs, modulesPath, lib, inputs, ... }:

{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
    ../services/spa.nix
  ];

  # comment this to break on perl dependencies
  system.forbiddenDependenciesRegexes = lib.mkForce [];

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
}
```

<!-- end_slide -->

# Local VM Demo

```nix
# configurations/spa-qemu.nix
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
```

```bash
nix run .#run-vm
# qemu boots spa-vm, port 8080 forwarded from host -> guest:80
# demo root password: demo1234 (local use only)
open http://localhost:8080
```

<!-- end_slide -->

# Test your service with NixOS Tests

```nix
# tests/spa-vm-test.nix
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
```

- `nix flake check` boots the VM in qemu and insists the SPA shell renders.
- `nix build -L .#checks.x86_64-linux.spa-vm`
- Passing `inputs` mirrors the real profile wiring, so regressions trip here first.
- Extend the script with health probes, migrations, or API smoke tests as the app grows.

<!-- end_slide -->

# Build Cloud Images (Hello Packer)

```nix
# configurations/spa-ami.nix
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
```

```bash
nix build .#spa-ami
nixos-rebuild build-image --flake .#spa-vm --image-variant vmware
```

- Outputs land in `./result`; run `du -h result/*` to stash size numbers for the talk.
- `.#spa-ami` is a flake package, so CI can build the tarball without `nixos-rebuild`.

<!-- end_slide -->

# Checking the system closure

- Expect system closures to be larger than the layered OCI image: kernel + system closure.
- Amazon tarball has additional cloud agent bits; note the compressed size.
- Run `nix path-info -sSrh .#nixosConfigurations.spa-ami.config.system.build.toplevel` to record the closure size, and keep an eye on it after tweaks.
- Use `nix why-depends` on that toplevel if size jumps (e.g., SSM agent or amazon-init pulling in git/perl) so you can justify or trim the extra weight.

<!-- end_slide -->

# Deploy Existing Hardware with NixOS-anywhere

See `configuration/spa-hetzner.nix`

```bash
# Spin up fresh hardware with your SSH key
hcloud server create \
  --type cx23 \
  --image debian-12 \
  --ssh-key my-key \
  --name spa-anywhere

# Push the SPA system straight onto the node
nixos-anywhere \
  --flake .#spa-hetzner \
  root@<server-ip>
```

- The Hetzner profile pulls in `inputs.disko` for partitioning and `inputs.srvos` for cloud defaults.
- `nixos-anywhere` copies the closure, provisions disks, and activates the profile in one go.
- Reuse the same profile for on-prem hosts—just adjust the `disko` layout or SSH keys.
- Great story for regulated customers who cannot run your Docker image but crave immutability.

<!-- end_slide -->

# Known Issues & Downsides

- VM images balloon faster than OCI layers—monitor closure sizes and publish expectations.
- `nixos-rebuild build-image` + `nix flake check` are compute-heavy; cache or parallelise in CI.
- TLS certificates and other secrets still need post-boot injection (ACME, AWS Secrets Manager, etc.)—images stay immutable.
- macOS support is not great

<!-- end_slide -->

# Wrap-Up

- One codebase, two or more delivery targets: Docker layers and redistributable VMs.
- NixOS module system: check.
- VM tests keep the talk honest; size metrics tell the reproducibility story.
- `nixos-anywhere` lets us push the exact same system onto Hetzner Cloud or lab metal.
- We closed the loop from OCI builds to "bring-your-own hardware" installs.
- Nix makes software composable.

Thanks for listening!

Contact: jonas@numtide.com

Source: https://github.com/zimbatm/vm-image-nix-talk

<!-- end_slide -->
