# How (and why) to build minimal and reproducible Docker images with Nix

This repository contains a presentation and examples for building Docker images with Nix, presented at Nix Bern on June 26, 2025.

## Prerequisites

- Nix package manager with flakes enabled
- Docker (for running the built images)

## Running the Presentation

1. Enter the development shell:

   ```bash
   nix develop
   ```

2. Start the presentation:

   ```bash
   presenterm -X -x presentation.md
   ```

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

### Exploring the Images

Use `dive` to explore the layer structure:

```bash
# Examine the layers
dive hello-nix:latest
dive spa-nix:latest
```

## Key Benefits of Nix for Container Images

- **Reproducible**: Same inputs always produce the same outputs
- **Minimal**: Only include what your application actually needs
- **Cacheable**: Efficient layer sharing across different images
- **Transparent**: Complete dependency tracking and SBOM generation

## Files Structure

- `presentation.md` - The main presentation slides
- `hello.nix` - Simple hello world container example
- `spa/` - React SPA example with Dockerfile comparison
- `flake.nix` - Development environment setup
- `links.md` - Useful resources and links

## Development

The flake provides all necessary tools for the presentation:

- `presenterm` - For presenting the slides
- `crane` - For examining container manifests
- `jq` - For JSON processing
- `qrencode` - For generating QR codes
- `dive` - For exploring container layers
- `sbomnix` - For generating Software Bill of Materials
