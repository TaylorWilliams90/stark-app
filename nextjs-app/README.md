# stark-app

A containerised full-stack web application scaffolded entirely with **Terraform** and **Docker Desktop**.  
Demonstrates Infrastructure-as-Code (IaC) skills using the `kreuzwerker/docker` Terraform provider.

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js 14 (App Router, TypeScript) |
| Database | PostgreSQL 15 |
| Containers | Docker Desktop |
| IaC | Terraform (`kreuzwerker/docker ~> 3.0`) |

## Architecture

```
  ┌─────────────────────────────────────────────┐
  │            stark_network (bridge)            │
  │                                             │
  │  ┌──────────────────┐   ┌────────────────┐  │
  │  │   stark_web      │   │   db_service   │  │
  │  │   Next.js :3000  │──▶│  Postgres :5432│  │
  │  └────────┬─────────┘   └────────────────┘  │
  └───────────┼─────────────────────────────────┘
              │ port 3000
         ┌────▼────┐
         │ Browser │
         └─────────┘
```

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — running
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.0

## Quick Start

```bash
# 1. Initialise Terraform (downloads the Docker provider)
terraform init

# 2. Preview what will be created
terraform plan

# 3. Apply — builds the Next.js image and starts all containers
terraform apply

# 4. Open the app
open http://localhost:3000
```

## Tear Down

```bash
terraform destroy
```

This stops and removes all containers, the network, and the built image.

## Key Concepts Demonstrated

- **Terraform blocks vs arguments** — `networks_advanced { }` is a block, not `= [...]`
- **`docker_image` resource** — Terraform drives `docker build` for you
- **Multi-stage Dockerfile** — deps → builder → lean runner (no node_modules in prod)
- **`output = "standalone"`** in `next.config.js` — required for the containerised runner
- **Container networking** — containers address each other by name (`db_service`)
- **`depends_on`** — ensures the DB starts before the web app
