# 🐳 Docker Cheat Sheet

> A comprehensive reference for Docker commands, Dockerfile instructions, and Docker Compose — curated for DevOps engineers and developers.

---

## Table of Contents

- [Core Concepts](#core-concepts)
- [Installation & Version](#installation--version)
- [Troubleshooting: First Steps](#troubleshooting-first-steps)
- [Images](#images)
- [Containers](#containers)
- [Volumes](#volumes)
- [Networks](#networks)
- [Dockerfile Reference](#dockerfile-reference)
- [Docker Compose](#docker-compose)
- [System & Cleanup](#system--cleanup)
- [Logs & Inspection](#logs--inspection)
- [Registry & Authentication](#registry--authentication)
- [Security Essentials](#security-essentials)
- [Common Patterns](#common-patterns)

---

## Core Concepts

| Concept | Description |
|---|---|
| **Image** | Read-only template used to create containers |
| **Container** | Runnable instance of an image |
| **Volume** | Persistent storage managed by Docker |
| **Network** | Isolated communication layer between containers |
| **Registry** | Storage and distribution service for images (e.g. Docker Hub, GHCR, ACR) |
| **Dockerfile** | Text file with instructions to build an image |
| **Compose** | Tool to define and run multi-container applications |
| **Context** | Build context sent to the Docker daemon |

---

## Installation & Version

```bash
# Check Docker version
docker --version
docker version          # client + server details

# Check Docker system info
docker info

# Check Docker Compose version
docker compose version
```

---

## Troubleshooting: First Steps

> Run these commands first when something isn't working. They cover ~80% of common issues.

### Is Docker running?

```bash
# Check daemon status
docker info
systemctl status docker          # Linux (systemd)
```

### What is running (or not)?

```bash
# All containers — including stopped ones
docker ps -a

# Why did a container stop? (exit code + error)
docker inspect mycontainer --format '{{.State.Status}} (exit {{.State.ExitCode}})'
docker inspect mycontainer --format '{{.State.Error}}'
```

### Check logs first

```bash
# Last 50 lines
docker logs --tail 50 mycontainer

# With timestamps
docker logs --timestamps --tail 100 mycontainer

# Follow live output
docker logs -f mycontainer

# Compose: logs from all services
docker compose logs --tail 50
docker compose logs -f app
```

### Resource exhaustion

```bash
# Live CPU / memory / network / disk I/O per container
docker stats

# Single snapshot (no TTY needed, e.g. in a script)
docker stats --no-stream

# Disk usage: images, containers, volumes, build cache
docker system df
```

### Networking issues

```bash
# Check port mappings
docker port mycontainer

# Inspect which network a container is on and its IP
docker inspect mycontainer --format '{{json .NetworkSettings.Networks}}' | jq

# List networks
docker network ls

# Test connectivity from inside the container
docker exec mycontainer ping db
docker exec mycontainer curl -s http://app:3000/health

# Debug with netshoot (Swiss-army network toolkit)
docker run -it --rm --network container:mycontainer nicolaka/netshoot
```

### Image / build issues

```bash
# List local images (check if the image actually exists)
docker images

# Rebuild without cache
docker build --no-cache -t myapp:latest .

# Inspect image layers to spot large or unexpected layers
docker history myapp:latest

# Pull a fresh copy of a base image
docker pull node:20-alpine
```

### Volume & permissions issues

```bash
# List volumes and confirm the right one is mounted
docker volume ls
docker volume inspect mydata

# Check what user the process runs as inside the container
docker exec mycontainer id
docker exec mycontainer ls -la /app
```

### Common exit codes

| Exit Code | Meaning | Common Cause |
|---|---|---|
| `0` | Success | Container completed normally |
| `1` | General error | Application crash / unhandled exception |
| `125` | Docker daemon error | Invalid `docker run` flag or option |
| `126` | Permission denied | Entrypoint not executable |
| `127` | Command not found | Binary missing in image |
| `137` | OOM kill (`SIGKILL`) | Container exceeded memory limit |
| `139` | Segmentation fault | Application or native library bug |
| `143` | Graceful shutdown (`SIGTERM`) | Normal `docker stop` |

### Compose-specific

```bash
# Validate compose file syntax
docker compose config

# Check service health status
docker compose ps

# Restart a single service without rebuilding
docker compose restart app

# Force recreate a service (picks up config changes)
docker compose up -d --force-recreate app

# Tail logs for multiple services
docker compose logs -f app db
```

---

## Images

### Pull, List & Remove

```bash
# Pull an image from a registry
docker pull nginx
docker pull nginx:1.27-alpine       # specific tag

# List local images
docker images
docker image ls

# Remove an image
docker rmi nginx
docker image rm nginx:1.27-alpine

# Remove all dangling (untagged) images
docker image prune

# Remove all unused images
docker image prune -a
```

### Build

```bash
# Build an image from a Dockerfile in the current directory
docker build -t myapp:1.0 .

# Build with a specific Dockerfile
docker build -f Dockerfile.prod -t myapp:prod .

# Build with build arguments
docker build --build-arg ENV=production -t myapp:prod .

# Build with no cache
docker build --no-cache -t myapp:latest .

# Multi-platform build (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest --push .
```

### Tag & Push

```bash
# Tag an image
docker tag myapp:latest myregistry.azurecr.io/myapp:1.0

# Push to a registry
docker push myregistry.azurecr.io/myapp:1.0

# Save image to a tar archive
docker save -o myapp.tar myapp:latest

# Load image from a tar archive
docker load -i myapp.tar
```

### Inspect

```bash
# Inspect image metadata
docker image inspect nginx

# Show image build history / layers
docker history nginx

# Show image digest
docker image inspect nginx --format='{{.RepoDigests}}'
```

---

## Containers

### Run

| Flag | Description |
|---|---|
| `-d` | Detached (background) mode |
| `-it` | Interactive TTY |
| `--name` | Assign a container name |
| `-p HOST:CONTAINER` | Publish port |
| `-v HOST:CONTAINER` | Bind mount a volume |
| `--env` / `-e` | Set environment variable |
| `--env-file` | Load env vars from a file |
| `--rm` | Auto-remove container on exit |
| `--network` | Connect to a network |
| `--restart` | Restart policy (`no`, `always`, `on-failure`, `unless-stopped`) |
| `--memory` | Memory limit (e.g. `512m`) |
| `--cpus` | CPU limit (e.g. `1.5`) |
| `--read-only` | Mount root FS as read-only |
| `--user` | Run as a specific user |

```bash
# Run a container in the background
docker run -d --name webserver -p 8080:80 nginx

# Run interactively and remove on exit
docker run -it --rm ubuntu bash

# Run with environment variables
docker run -d -e DB_HOST=db -e DB_PORT=5432 myapp

# Run with env file
docker run -d --env-file .env myapp

# Run with resource limits
docker run -d --memory=512m --cpus=1.5 myapp

# Run as non-root user
docker run -d --user 1000:1000 myapp
```

### Lifecycle

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Start / stop / restart
docker start mycontainer
docker stop mycontainer
docker restart mycontainer

# Pause / unpause
docker pause mycontainer
docker unpause mycontainer

# Kill (send SIGKILL)
docker kill mycontainer

# Remove a stopped container
docker rm mycontainer

# Force-remove a running container
docker rm -f mycontainer

# Remove all stopped containers
docker container prune
```

### Execute & Access

```bash
# Open a shell in a running container
docker exec -it mycontainer bash
docker exec -it mycontainer sh          # for Alpine-based images

# Run a one-off command
docker exec mycontainer ls /app

# Copy files to/from a container
docker cp mycontainer:/app/config.yaml ./config.yaml
docker cp ./config.yaml mycontainer:/app/config.yaml

# Attach to a running container's STDIN/STDOUT
docker attach mycontainer
```

---

## Volumes

```bash
# Create a named volume
docker volume create mydata

# List volumes
docker volume ls

# Inspect a volume
docker volume inspect mydata

# Remove a volume
docker volume rm mydata

# Remove all unused volumes
docker volume prune

# Mount a named volume
docker run -d -v mydata:/var/lib/mysql mysql

# Bind mount a host directory
docker run -d -v $(pwd)/data:/app/data myapp

# Read-only bind mount
docker run -d -v $(pwd)/config:/app/config:ro myapp

# tmpfs mount (in-memory, not persisted)
docker run -d --tmpfs /tmp myapp
```

---

## Networks

### Network Types

| Driver | Description |
|---|---|
| `bridge` | Default. Isolated network on a single host |
| `host` | Shares host's network stack (Linux only) |
| `none` | No networking |
| `overlay` | Multi-host networking (Swarm/Kubernetes) |
| `macvlan` | Assigns a MAC address, appears as physical device |

```bash
# List networks
docker network ls

# Create a network
docker network create mynet
docker network create --driver bridge mynet

# Connect a running container to a network
docker network connect mynet mycontainer

# Disconnect a container from a network
docker network disconnect mynet mycontainer

# Inspect a network
docker network inspect mynet

# Remove a network
docker network rm mynet

# Remove all unused networks
docker network prune

# Run a container on a specific network
docker run -d --network mynet --name app myapp
```

---

## Dockerfile Reference

### Instructions

| Instruction | Description |
|---|---|
| `FROM` | Base image |
| `LABEL` | Add metadata key=value pairs |
| `ARG` | Build-time variable |
| `ENV` | Runtime environment variable |
| `WORKDIR` | Set working directory |
| `COPY` | Copy files from build context |
| `ADD` | Like COPY, also supports URLs and tar extraction |
| `RUN` | Execute command during build |
| `EXPOSE` | Document the port the container listens on |
| `VOLUME` | Create a mount point |
| `USER` | Set the user for subsequent instructions |
| `CMD` | Default command / arguments (overridable) |
| `ENTRYPOINT` | Fixed executable (CMD provides args) |
| `HEALTHCHECK` | Define a container health check |
| `ONBUILD` | Trigger instructions for downstream images |

### Production-Ready Dockerfile Example

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Runtime
FROM node:20-alpine AS runtime

# Security: add labels
LABEL maintainer="team@example.com" \
      version="1.0.0"

# Security: run as non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only what is needed from the build stage
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=appuser:appgroup . .

# Security: drop root
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
```

### .dockerignore

```
# .dockerignore
node_modules/
.git/
.env
*.log
dist/
coverage/
.DS_Store
```

---

## Docker Compose

### compose.yaml Structure

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - BUILD_ENV=production
    image: myapp:latest
    container_name: app
    restart: unless-stopped
    ports:
      - "8080:3000"
    environment:
      - NODE_ENV=production
    env_file:
      - .env
    volumes:
      - app_data:/app/data
    networks:
      - backend
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 10s
      timeout: 5s
      retries: 5
    secrets:
      - db_password

volumes:
  app_data:
  db_data:

networks:
  backend:
    driver: bridge

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

### Compose Commands

```bash
# Start services (build if needed)
docker compose up -d

# Start and force rebuild
docker compose up -d --build

# Stop services (keep containers)
docker compose stop

# Stop and remove containers, networks
docker compose down

# Stop and remove containers, networks, volumes
docker compose down -v

# View running services
docker compose ps

# View logs
docker compose logs
docker compose logs -f app          # follow logs for a specific service

# Scale a service
docker compose up -d --scale app=3

# Run a one-off command in a service container
docker compose run --rm app sh

# Execute a command in a running service container
docker compose exec app bash

# Pull latest images
docker compose pull

# Validate compose file
docker compose config
```

---

## System & Cleanup

```bash
# Show disk usage
docker system df
docker system df -v                 # verbose

# Remove all stopped containers, unused networks,
# dangling images, and build cache
docker system prune

# Full cleanup (including unused images and volumes) — USE WITH CAUTION
docker system prune -a --volumes

# Remove build cache only
docker builder prune
docker builder prune -a             # remove all build cache
```

---

## Logs & Inspection

```bash
# View container logs
docker logs mycontainer
docker logs -f mycontainer         # follow
docker logs --tail 100 mycontainer
docker logs --since 1h mycontainer
docker logs --timestamps mycontainer

# Inspect a container (full JSON metadata)
docker inspect mycontainer

# Format inspect output
docker inspect mycontainer --format '{{.NetworkSettings.IPAddress}}'
docker inspect mycontainer --format '{{.State.Status}}'

# View real-time resource usage
docker stats
docker stats mycontainer --no-stream        # single snapshot

# View running processes inside a container
docker top mycontainer

# View port mappings
docker port mycontainer
```

---

## Registry & Authentication

```bash
# Log in to Docker Hub
docker login

# Log in to a private registry
docker login myregistry.azurecr.io

# Log out
docker logout myregistry.azurecr.io

# Search Docker Hub
docker search nginx

# Pull from GitHub Container Registry (GHCR)
docker pull ghcr.io/owner/image:tag

# Pull from Azure Container Registry (ACR)
az acr login --name myregistry
docker pull myregistry.azurecr.io/myapp:1.0
```

---

## Security Essentials

| Practice | How |
|---|---|
| Run as non-root | `USER 1000` in Dockerfile |
| Read-only filesystem | `docker run --read-only` |
| Drop Linux capabilities | `docker run --cap-drop ALL --cap-add NET_BIND_SERVICE` |
| No new privileges | `docker run --security-opt no-new-privileges` |
| Limit resources | `--memory`, `--cpus` flags |
| Scan images for CVEs | `docker scout cves myapp:latest` |
| Use secrets, not env vars | `docker secret` / Compose `secrets:` block |
| Pin base image tags | Use `nginx:1.27.4-alpine` not `nginx:latest` |
| Use `.dockerignore` | Prevent secrets/source leaking into image |
| Sign images | `docker trust sign myapp:latest` |

```bash
# Scan an image for vulnerabilities (Docker Scout)
docker scout cves myapp:latest
docker scout quickview myapp:latest

# Run with minimal capabilities
docker run -d \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --memory=256m --cpus=0.5 \
  --user 1000:1000 \
  myapp:latest
```

---

## Common Patterns

### Override CMD / ENTRYPOINT

```bash
# Override CMD
docker run myapp echo "hello"

# Override ENTRYPOINT
docker run --entrypoint sh myapp -c "ls /app"
```

### Pass Secrets Safely (never use -e for secrets)

```bash
# Use a secrets file
docker run -d \
  --mount type=secret,id=db_pass,target=/run/secrets/db_pass \
  myapp
```

### Multi-Stage Build (reduce final image size)

```dockerfile
FROM golang:1.22 AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app /app
ENTRYPOINT ["/app"]
```

### Health Check Wait Pattern (Compose)

```yaml
depends_on:
  db:
    condition: service_healthy
```

### Debugging a Distroless / Scratch Container

```bash
# Attach an ephemeral debug container sharing namespaces
docker debug mycontainer
# or using kubectl equivalent for Docker:
docker run -it --pid=container:mycontainer --network=container:mycontainer \
  --cap-add SYS_PTRACE nicolaka/netshoot
```

### Environment-Specific Overrides

```bash
# Merge a production override file
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

---

## Quick Reference Card

```
docker build -t name:tag .              # Build image
docker pull image:tag                   # Pull image
docker push image:tag                   # Push image
docker run -d -p host:cont image        # Run container (detached)
docker run -it --rm image sh            # Interactive shell (auto-remove)
docker exec -it name bash               # Shell into running container
docker ps -a                            # List all containers
docker logs -f name                     # Follow container logs
docker stop name && docker rm name      # Stop and remove container
docker system prune -a                  # Full cleanup (careful!)
docker compose up -d --build            # Start Compose stack
docker compose down -v                  # Tear down Compose stack + volumes
docker stats                            # Live resource usage
docker scout cves image:tag             # Scan for CVEs
```

---

> **Tip:** Use `docker help <command>` or `docker <command> --help` for detailed usage on any command.
