terraform {
  required_providers {
    # Runs shell commands — used to create/destroy the k3d cluster
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    # Reads local files and renders templates
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    # Applies Kubernetes manifests once the cluster is up
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

# ─────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────
variable "postgres_user" {
  type        = string
  description = "PostgreSQL username"
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL password"
  sensitive   = true
}

variable "postgres_db" {
  type        = string
  description = "PostgreSQL database name"
}

variable "cluster_name" {
  type        = string
  description = "k3d cluster name"
}

variable "app_replicas" {
  type        = number
  description = "Number of Next.js pod replicas"
}

# ─────────────────────────────────────────────
# 1. Create the k3d cluster
#    - 1 control plane node
#    - 2 worker nodes (agents)
#    - Port 8080 on host → port 80 on the cluster LoadBalancer
# ─────────────────────────────────────────────
resource "null_resource" "k3d_cluster" {
  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command     = "k3d cluster create ${var.cluster_name} --agents 2 --port 8080:80@loadbalancer --wait"
    interpreter = ["cmd", "/C"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name}"
  }
}

# ─────────────────────────────────────────────
# 2. Build Next.js image and import into k3d
#    k3d clusters can't pull local images directly —
#    we build it then import it with k3d image import.
# ─────────────────────────────────────────────
resource "null_resource" "build_nextjs_image" {
  triggers = {
    dir_sha = sha1(join("", [
      for f in fileset("${path.module}/nextjs-app/src", "**") :
      filesha1("${path.module}/nextjs-app/src/${f}")
    ]))
  }

  provisioner "local-exec" {
    command     = "docker build -t stark-nextjs:latest ${path.module}/nextjs-app && k3d image import stark-nextjs:latest -c ${var.cluster_name}"
    interpreter = ["cmd", "/C"]
  }

  depends_on = [null_resource.k3d_cluster]
}

# ─────────────────────────────────────────────
# 3. Kubernetes provider
#    Uses exec to call k3d at apply time only —
#    avoids Terraform validating a kubeconfig path
#    during plan before the cluster exists.
# ─────────────────────────────────────────────
provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "k3d-stark-cluster"
}




# ─────────────────────────────────────────────
# 4. Namespace — isolates all Stark resources
# ─────────────────────────────────────────────
resource "kubernetes_namespace" "stark" {
  metadata {
    name = "stark"
  }

  depends_on = [null_resource.k3d_cluster]
}

# ─────────────────────────────────────────────
# 5. Secret — stores DB credentials as base64
#    Never put raw passwords in ConfigMaps.
# ─────────────────────────────────────────────
resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  data = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = var.postgres_db
    DATABASE_URL      = "postgresql://${var.postgres_user}:${var.postgres_password}@postgres-service:5432/${var.postgres_db}?schema=public"
  }

  type = "Opaque"
}

# ─────────────────────────────────────────────
# 6. Postgres PersistentVolumeClaim
#    Requests 1Gi from k3d's default
#    local-path StorageClass.
# ─────────────────────────────────────────────
resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

# ─────────────────────────────────────────────
# 7. Postgres ConfigMap — SQL init scripts
#    Mounted into the container on first startup.
# ─────────────────────────────────────────────
resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  data = {
    "01_schema.sql" = file("${path.module}/init-db/01_schema.sql")
    "02_seed.sql"   = file("${path.module}/init-db/02_seed.sql")
  }
}

# ─────────────────────────────────────────────
# 8. Postgres StatefulSet
#    StatefulSet gives stable pod names and
#    ordered startup — important for databases.
# ─────────────────────────────────────────────
resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  wait_for_rollout = false

  spec {
    service_name = "postgres-service"
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          port {
            container_port = 5432
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "postgres"
          }

          volume_mount {
            name       = "postgres-init"
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_user, "-d", var.postgres_db]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_user, "-d", var.postgres_db]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "postgres-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }

        volume {
          name = "postgres-init"
          config_map {
            name = kubernetes_config_map.postgres_init.metadata[0].name
          }
        }
      }
    }
  }
}

# ─────────────────────────────────────────────
# 9. Postgres Service (ClusterIP)
#    Internal only — Postgres is never exposed
#    outside the cluster.
# ─────────────────────────────────────────────
resource "kubernetes_service" "postgres_service" {
  metadata {
    name      = "postgres-service"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# 10. Next.js ConfigMap — non-secret env vars
# ─────────────────────────────────────────────
resource "kubernetes_config_map" "nextjs_config" {
  metadata {
    name      = "nextjs-config"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  data = {
    NODE_ENV = "production"
  }
}

# ─────────────────────────────────────────────
# 11. Next.js Deployment — 3 replicas
#     Rolling updates ensure zero downtime deploys.
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "nextjs" {
  metadata {
    name      = "nextjs"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  wait_for_rollout = false

  spec {
    replicas = var.app_replicas

    selector {
      match_labels = {
        app = "nextjs"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    template {
      metadata {
        labels = {
          app = "nextjs"
        }
      }

      spec {
        container {
          name  = "nextjs"
          image = "stark-nextjs:latest"

          # Never pull — image was imported locally via k3d
          image_pull_policy = "Never"

          port {
            container_port = 3000
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "DATABASE_URL"
              }
            }
          }

          env {
            name = "NODE_ENV"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.nextjs_config.metadata[0].name
                key  = "NODE_ENV"
              }
            }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_stateful_set.postgres,
    null_resource.build_nextjs_image,
  ]
}

# ─────────────────────────────────────────────
# 12. Next.js LoadBalancer Service
#     Distributes traffic across all 3 pods.
#     k3d maps this to host port 8080 via Traefik.
# ─────────────────────────────────────────────
resource "kubernetes_service" "nextjs_service" {
  metadata {
    name      = "nextjs-service"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  wait_for_load_balancer = false

  spec {
    selector = {
      app = "nextjs"
    }

    port {
      port        = 80
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}

# ─────────────────────────────────────────────
# 13. HorizontalPodAutoscaler
#     Scales Next.js between 3–10 replicas
#     based on CPU utilisation.
# ─────────────────────────────────────────────
resource "kubernetes_horizontal_pod_autoscaler_v2" "nextjs_hpa" {
  metadata {
    name      = "nextjs-hpa"
    namespace = kubernetes_namespace.stark.metadata[0].name
  }

  spec {
    min_replicas = var.app_replicas
    max_replicas = 10

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.nextjs.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}


# ─────────────────────────────────────────────
# 14. Ingress — tells Traefik to route
#     localhost:8080 → nextjs-service:80
# ─────────────────────────────────────────────
resource "kubernetes_ingress_v1" "nextjs_ingress" {
  metadata {
    name      = "nextjs-ingress"
    namespace = kubernetes_namespace.stark.metadata[0].name
    annotations = {
      "ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nextjs_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = false
}

# ─────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────
output "app_url" {
  description = "URL to access the Next.js app"
  value       = "http://localhost:8080"
}

output "cluster_name" {
  description = "k3d cluster name"
  value       = var.cluster_name
}

output "nextjs_replicas" {
  description = "Number of Next.js replicas"
  value       = var.app_replicas
}
