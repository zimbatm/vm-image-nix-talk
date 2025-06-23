---
title: "How (and why) to build minimal and reproducible Docker images with Nix"
sub_title: "Nix Bern, 26.06.2025"
author: "Yannik Dällenbach"
---

# Who Am I?

- Work @ bespinian
- Mainly building platforms on top of Kubernetes...
- ...to later move applications there

<!-- end_slide -->

# What We'll Cover

1. Introdcution to OCI containers
2. Nix terminology
3. Docker vs Nix approach
4. Examples

<!-- end_slide -->

# Understanding OCI Containers

## What is an OCI Container?

- **OCI** = Open Container Initiative
- Standard for container formats
  - **OCI Image Format**
  - OCI Runtime Specification
- Docker images **are** OCI containers
- Just a fancy tarball with metadata

<!-- end_slide -->

# Understanding OCI Containers

## OCI Container Image Structure

```
Container Image
├── Layer 1: Base OS files
├── Layer 2: Runtime (Python, Node, etc.)
├── Layer 3: Dependencies
├── Layer 4: Your application
└── manifest.json
```

<!-- end_slide -->

# Understanding OCI Containers

## Check Out The Manifest

```bash +exec
crane manifest \
    --platform=linux/arm64 \
    node:lts | jq '. | keys'
```

<!-- end_slide -->

# Understanding OCI Containers

## How Layers Work

- Each layer = filesystem changes
- Layers stack on top of each other
- Final container = merged view of all layers
- Union filesystem makes the magic happen

---

```bash +exec
crane manifest \
    --platform=linux/arm64 \
    node:lts | jq '.layers'
```

<!-- end_slide -->

# Understanding OCI Containers

## How Layers Work

```bash +exec +acquire_terminal
dive node:lts
```

<!-- end_slide -->

# Understanding OCI Containers

## Why Layers Matter

### Caching Benefits:

- Only rebuild changed layers
- Share common layers between images
- Faster builds and smaller downloads

### Problems:

- Layer order matters
- Cache invalidation can be tricky
- `RUN apt-get update` breaks everything

<!-- end_slide -->

# Nix Terminology

## What is Nix?

Three things with the same name:

1. **Nix language** - functional language for packages
2. **Nix package manager** - builds packages deterministically
3. **NixOS** - Linux distribution built on Nix

We're using #1 and #2 today!

<!-- end_slide -->

# Nix Terminology

## Key Concept: Derivation

**Derivation** = recipe for building something

```nix +line_numbers
stdenv.mkDerivation {
  name = "hello-world";
  src = ./src;
  buildPhase = "gcc -o hello hello.c";
  installPhase = "mkdir -p $out/bin && cp hello $out/bin/";
}
```

Think: "Makefile" but functional and pure

<!-- end_slide -->

# Nix Terminology

## Key Concept: Store Path

- `/nix/store/abc123-package-name/`
- Unique hash based on inputs
- Same inputs = same hash = same result
- **Reproducible builds!**

<!-- end_slide -->

# Nix Terminology

## Key Concept: Closure

**Closure** = Nix package + all its dependencies

```
my-app closure:
├── my-app
├── python3
├── glibc
├── linux-headers
└── gcc-libs
```

Nix knows the complete dependency graph!

<!-- end_slide -->

# Nix Terminology

## Key Concept: Flake

Flake = Modern way to define Nix projects

```nix
{
  description = "My project description";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = { nixpkgs, ... }: {
    # Your packages, apps, dev shells here
  };
}
```

Think: "package.json" or "Cargo.toml" but for Nix

- **Reproducible** - locks input versions
- **Portable** - works everywhere Nix runs
- **Self-contained** - describes everything needed

<!-- end_slide -->

# Docker vs Nix Approach

<!-- column_layout: [2, 1] -->
<!-- column: 0 -->

## Traditional Docker Build

```docker {1|4-5|9|11|14|17|all} +line_numbers
FROM node:lts AS build
WORKDIR /build

COPY package.json package-lock.json .
RUN npm ci

COPY . .

RUN npm run build

FROM caddy:2
WORKDIR /run

COPY --from=build /build/dist/ .

EXPOSE 80/tcp
ENTRYPOINT [ "caddy", "file-server", "--root=/run" ]
```

<!--pause-->
<!-- column: 1 -->

## Docker Layer Reality

```text
Layer 1: Ubuntu base (100MB)
Layer 2: Node.js + npm + build tools (200MB)
Layer 3: Dependencies from npm ci (50MB)
Layer 4: Your app source code (1MB)
Layer 5: Caddy base (20MB)
Layer 6: Your built app (5MB)
```

**Total: ~376MB** (lots of duplication!)

<!-- end_slide -->

# Docker vs Nix Approach

<!-- column_layout: [2, 1] -->

<!-- column: 0 -->

## Nix (Flake) Approach

```nix {all|10|14-26|all} +line_numbers
{
  description = "An example of a SPA";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages = {
          default = pkgs.buildNpmPackage {
            # ...
          };

          docker = pkgs.dockerTools.buildLayeredImage {
            name = "spa-nix";
            tag = "latest";

            config = {
              Entrypoint = [
                "${pkgs.caddy}/bin/caddy"
                "file-server"
                "--root=${self.packages.${system}.default}"
              ];
              ExposedPorts = { "80/tcp" = { }; };
            };
          };
        };
      });
}
```

<!--pause-->

<!-- column: 1 -->

## Nix Layer Reality

```text
Layer 1: glibc (2MB)
Layer 2: caddy binary (15MB)
Layer 3: your built SPA (5MB)
```

**Total: ~22MB** (only what you need!)

<!-- end_slide -->

# Our first Container

<!-- column_layout: [1, 1] -->
<!-- column: 0 -->

Let's build a "Hello World" container:

```file {all|1|3|5|all} +line_numbers
path: hello.nix
language: nix
```

<!-- column: 1 -->

<!--pause-->

### Build

```bash +exec
nix-build hello.nix
```

<!--pause-->

### Load into Docker

```bash +exec
docker load < result
```

<!--pause-->

### Run it!

```bash +exec
docker run hello-nix:latest
```

<!-- end_slide -->

# Multi-Layer Example

<!-- column_layout: [2, 1] -->
<!-- column: 0 -->

```file {all|1-16|18|18-31|all} +line_numbers
path: spa/flake.nix
language: nix
start_line: 14
end_line: 43
```

<!-- column: 1 -->

<!-- pause -->

```bash +exec
/// cd spa
nix build .#docker
```

<!-- end_slide -->

# Multi-Layer Example

<!-- column_layout: [2, 1] -->
<!-- column: 0 -->

```file +line_numbers
path: spa/flake.nix
language: nix
start_line: 14
end_line: 43
```

<!-- column: 1 -->

```bash +exec
/// cd spa
docker load -i result
```

<!-- end_slide -->

# Multi-Layer Example

<!-- column_layout: [2, 1] -->
<!-- column: 0 -->

```file +line_numbers
path: spa/flake.nix
language: nix
start_line: 14
end_line: 43
```

<!-- column: 1 -->

```bash +exec +acquire_terminal
/// cd spa
dive spa-nix
```

<!-- end_slide -->

# Why Layered?

- Each package gets its own layer
- Share layers between different images
- Update only what changed
- Better caching across your entire project

<!--pause-->

---

## Layer Sharing Example

```text
Image A (Flask app):     Image B (Django app):
├── glibc               ├── glibc ← SHARED!
├── python3             ├── python3 ← SHARED!
├── flask               ├── django
└── app-a               └── app-b
```

Push once, use everywhere!

<!--end_slide-->

# Bonus: What about SBOM?

```bash +exec
/// cd spa
sbomnix result
```

<!--end_slide-->

# What about SBOM?

```bash +exec
/// cd spa
cat sbom.spdx.json | jq
```

<!--end_slide-->

# Key Takeaways

✅ Reproducible - same inputs, same outputs

✅ Minimal - only what you need

✅ Cacheable - share layers efficiently

<!--end_slide-->

# Questions?

<!--end_slide-->

# Links

```bash +exec_replace +no_background
qrencode -t ANSI -m 2 -o - https://github.com/ioboi/container-image-nix-talk/blob/main/links.md
```

https://github.com/ioboi/container-image-nix-talk/blob/main/links.md
