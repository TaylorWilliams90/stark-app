terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

# ─────────────────────────────────────────────
# 1. Private Network
#    Containers on this network can reach each
#    other by name (e.g. "db_service").
# ─────────────────────────────────────────────
resource "docker_network" "app_network" {
  name = "stark_network"
}

# ─────────────────────────────────────────────
# 2. Build the Next.js image from ./nextjs-app
#    Terraform will run `docker build` for you.
# ─────────────────────────────────────────────
resource "docker_image" "nextjs_app" {
  name = "stark-nextjs:latest"

  build {
    context    = "${path.module}/nextjs-app"
    dockerfile = "Dockerfile"
  }

  # Rebuild the image whenever any source file changes
  triggers = {
    dir_sha = sha1(join("", [
      for f in fileset("${path.module}/nextjs-app/src", "**") :
      filesha1("${path.module}/nextjs-app/src/${f}")
    ]))
  }
}

# ─────────────────────────────────────────────
# 3. PostgreSQL Database Container
# ─────────────────────────────────────────────
resource "docker_container" "db_server" {
  name  = "db_service"
  image = "postgres:15"

  # FIX: networks_advanced is a BLOCK, not an argument.
  # Remove the `=` sign — blocks use { } directly.
  networks_advanced {
    name = docker_network.app_network.name
  }

  env = [
    "POSTGRES_USER=admin",
    "POSTGRES_PASSWORD=secretpassword",
    "POSTGRES_DB=myapp_db"
  ]

  # Keep the container running if Docker restarts
  restart = "unless-stopped"
}

# ─────────────────────────────────────────────
# 4. Next.js Web App Container
# ─────────────────────────────────────────────
resource "docker_container" "web_app" {
  name  = "stark_web"
  image = docker_image.nextjs_app.image_id

  networks_advanced {
    name = docker_network.app_network.name
  }

  env = [
    # The hostname is the *container name* of the DB, not localhost
    "DATABASE_URL=postgres://admin:secretpassword@db_service:5432/myapp_db",
    "NODE_ENV=production"
  ]

  ports {
    internal = 3000
    external = 3000
  }

  restart = "unless-stopped"

  # Don't start the web app until the DB container exists
  depends_on = [docker_container.db_server]
}
