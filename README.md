# How (and why) to build minimal and reproducible Docker images with Nix

This repository contains a presentation and examples for building Docker images with Nix, presented at Nix Bern on June 26, 2025.

## Prerequisites

- Nix package manager with flakes enabled
- Docker (for running the built images)

## Presentations

### Minimal OCI Images with Nix

1. Enter the development shell:

   ```bash
   nix develop
   ```

2. Start the container talk:

   ```bash
   presenterm -X -x presentation.md
   ```

### Building Redistributable VMs with NixOS

1. Enter the same development shell:

   ```bash
   nix develop
   ```

2. Launch the VM-focused talk:

   ```bash
   presenterm -X -x presentation-vm.md
   ```

Both decks share the tooling in the dev shell (now including `nixos-rebuild` and `qemu`) so you can swap between them without leaving the environment.

## Examples

### Simple Hello World Container

Build a minimal container that runs the `hello` program:

```bash
# Build the image
nix-build hello.nix

# Load into Docker
docker load < result

# Run it
docker run hello-nix:latest
```

### Multi-layered SPA Container

The `spa/` directory contains a React SPA example that demonstrates:

- Building a Node.js application with Nix
- Creating a layered Docker image
- Serving static files with Caddy
- Alternative `container.nix` file to build a container to serve images using nginx

```bash
cd spa

# Build the Docker image
nix build .#docker

# Load into Docker
docker load < result

# Run the container
docker run -p 8080:80 spa-nix:latest
```

You can then visit http://localhost:8080 to see the running application.

Alternatively you can build the nginx based container image:

```bash
cd spa

# Build the Docker image
nix build -f container.nix

# Load into Docker
docker load < result

# Run the container
docker run -p 8080:80 spa-nix:latest
```

You can compare this image with the container image you can build using `Dockerfile.nginx`:

```bash
cd spa
docker build -t spa-docker -f Dockerfile.nginx .
```

### Exploring the Images

Use `dive` to explore the layer structure:

```bash
# Examine the layers
dive hello-nix:latest
dive spa-nix:latest
```

## VM Image Workflow

The same SPA can be turned into a NixOS VM image with first-class tooling:

```bash
# Build a local QCOW2 image and inspect its size
nixos-rebuild build-image --flake .#spa-vm --image-variant qcow2
du -h result/*

# Produce an AWS-compatible tarball (uses the built-in amazon image module)
nixos-rebuild build-image --flake .#spa-vm --image-variant amazon
du -h result/*

# Or build the AMI artifact directly via the flake package
nix build .#spa-ami
ls -lh result

# Spin up the VM locally for a quick demo (uses qemu under the hood)
nix run .#run-vm
```

> Note: older `nixos-generators` commands are no longer required—the functionality now lives inside `nixos-rebuild build-image`. You can still mention the project for historical context, but the new workflow keeps everything within the flake.

Once the VM is running you can visit http://localhost:8080 to reach the forwarded port and validate the SPA.

### Operational Considerations

- TLS certificates cannot ship inside immutable images—inject them via cloud-init snippets, an ACME client on first boot, or a secret manager (e.g., AWS SSM).
- Include other environment-specific data (logging endpoints, monitoring agents, SSH config) as separate Nix modules so the base image stays generic.
- The flake exports reusable modules under `.#nixosModules` so you can layer the SPA service into other systems or build cloud images.
- The local qemu profile (`.#spa-vm`) sets a demo root password (`demo1234`) for walkthroughs—rotate or disable it in any shared environment.

### Remote Installs with `nixos-anywhere`

The same flake exports a Hetzner-friendly profile that keeps SSH access available during installs:

```bash
# Create a new Hetzner Cloud server tied to your SSH key
hcloud server create \
  --type cx23 \
  --image debian-12 \
  --ssh-key my-key \
  --name spa-anywhere

# Push the SPA configuration directly onto the node
nixos-anywhere \
  --flake .#spa-hetzner \
  root@<server-ip>
```

The profile currently ships a demo SSH key (`zimbatm@p1`) in `users.users.root.openssh.authorizedKeys`; replace it with your own (or overlay one in) before running so the assertion passes with the credentials you control. Swap the target hostname/IP to point at any machine you can reach over SSH (bare metal, other clouds, lab hardware) and `nixos-anywhere` will provision it with the same system derivation.

The profile also ships a `disko` definition that partitions `/dev/sda` with a GRUB BIOS boot sector, EFI system partition, and ext4 root, so the remote installer can lay down disks deterministically. Adjust the layout if your target hardware exposes different devices (e.g., NVMe) before running the command.

## Key Benefits of Nix for Container Images

- **Reproducible**: Same inputs always produce the same outputs
- **Minimal**: Only include what your application actually needs
- **Cacheable**: Efficient layer sharing across different images
- **Transparent**: Complete dependency tracking and SBOM generation

## File Structure

- `presentation.md` - The main presentation slides
- `presentation-vm.md` - Companion deck covering the VM workflow
- `hello.nix` - Simple hello world container example
- `spa/` - React SPA example with Dockerfile comparison
- `nixos/services/` - Reusable NixOS modules (e.g., `spa.nix` wires the SPA into nginx)
- `nixos/profiles/` - Base machine profile (`spa-machine.nix`) consumed by every image
- `configurations/` - Target-specific system configs layered on top of the profile (qemu demo, AMI, Hetzner/NixOS-anywhere)
- `tests/` - NixOS VM tests to ensure the image serves the SPA
- `flake.nix` - Development environment setup
- `links.md` - Useful resources and links

## Development

The flake provides all necessary tools for the presentation:

- `presenterm` - For presenting the slides
- `nixos-rebuild` / `qemu` - For building and running VM images
- `crane` - For examining container manifests
- `jq` - For JSON processing
- `qrencode` - For generating QR codes
- `dive` - For exploring container layers
- `sbomnix` - For generating Software Bill of Materials
- `hcloud` - For managing Hetzner Cloud servers from the CLI
- `nixos-anywhere` - For pushing the configuration onto existing hosts

Run the automated checks before sharing updates:

```bash
nix flake check
```
