# Stark App

[![Next.js](https://img.shields.io/badge/Next.js-15.0-black?style=flat-square&logo=next.js)](https://nextjs.org/)
[![Terraform](https://img.shields.io/badge/Terraform-1.x-623CE4?style=flat-square&logo=terraform)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?style=flat-square&logo=docker)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-k3d-326CE5?style=flat-square&logo=kubernetes)](https://k3d.io/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?style=flat-square&logo=typescript)](https://www.typescriptlang.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-4169E1?style=flat-square&logo=postgresql)](https://www.postgresql.org/)

A containerized Next.js full-stack application orchestrated via Terraform on a local Kubernetes cluster (k3d). The stack includes a PostgreSQL database, load-balanced Next.js replicas, horizontal auto-scaling, and automated database seeding — all provisioned from a single `terraform apply`.

---

## 🏗️ Architecture

```
http://localhost:8080
        │
  k3d LoadBalancer (Traefik Ingress)
        │
  ┌─────────────────────────────┐
  │   nextjs pod 1  (port 3000) │
  │   nextjs pod 2  (port 3000) │  ← Round-robin load balanced
  │   nextjs pod 3  (port 3000) │  ← Auto-scales to 10 pods at 70% CPU
  └─────────────────────────────┘
        │
  postgres-0 (StatefulSet)
  ├── 1Gi PersistentVolumeClaim
  ├── users table (bcrypt passwords, roles, verified flag)
  └── sessions table
```

---

## 📋 Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | v20.10+ | Container runtime |
| [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) | v1.5+ | Infrastructure provisioning |
| [k3d](https://k3d.io/) | v5.x | Local Kubernetes cluster |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | v1.28+ | Cluster inspection |
| Node.js & npm | v20+ | Local development only |

---

## 🚀 Getting Started

### 1. Clone and configure

```bash
git clone <your-repo-url>
cd stark-app
```

Copy the example vars file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
postgres_user     = "stark_user"
postgres_password = "your-strong-password-here"
postgres_db       = "stark_db"
cluster_name      = "stark-cluster"
app_replicas      = 3
```

### 2. Add the health check route

Create `nextjs-app/app/api/health/route.ts`:

```ts
export async function GET() {
  return Response.json({ status: "ok" }, { status: 200 });
}
```

> This is required for Kubernetes liveness and readiness probes.

### 3. Deploy

```bash
terraform init
terraform apply
```

Terraform will:
1. Create a k3d cluster (1 server + 2 agents)
2. Build and import the Next.js Docker image
3. Deploy PostgreSQL as a StatefulSet with schema + seed data
4. Deploy 3 Next.js replicas behind a load balancer
5. Configure the Traefik ingress and HorizontalPodAutoscaler

Once complete, open **http://localhost:8080** in your browser.

### 4. Verify pods are running

```bash
kubectl get pods -n stark
```

Expected output:
```
NAME                      READY   STATUS    RESTARTS
nextjs-xxxxxxxxx-xxxxx    1/1     Running   0
nextjs-xxxxxxxxx-xxxxx    1/1     Running   0
nextjs-xxxxxxxxx-xxxxx    1/1     Running   0
postgres-0                1/1     Running   0
```

---

## 🗄️ Database

PostgreSQL is seeded automatically on first startup via init scripts in `init-db/`:

| File | Purpose |
|------|---------|
| `01_schema.sql` | Creates `users` and `sessions` tables |
| `02_seed.sql` | Inserts a default admin user |

> **Important:** Replace the placeholder bcrypt hash in `02_seed.sql` before deploying.
> Generate a real hash in Node.js:
> ```js
> const bcrypt = require('bcrypt');
> console.log(await bcrypt.hash('your-password', 10));
> ```

---

## 📁 Project Structure

```
stark-app/
├── nextjs-app/                   # Next.js application
│   ├── app/                      # App Router pages and API routes
│   │   └── api/health/route.ts   # Kubernetes health probe endpoint
│   ├── Dockerfile                # Multi-stage production build
│   ├── .dockerignore
│   ├── package.json
│   └── tsconfig.json
├── init-db/                      # Database init scripts (auto-run on first startup)
│   ├── 01_schema.sql
│   └── 02_seed.sql
├── main.tf                       # Terraform — full cluster + k8s resource definitions
├── terraform.tfvars              # Your local variable values (gitignored)
├── terraform.tfvars.example      # Safe-to-commit example vars
├── docker-compose.yml            # Local dev alternative (no k8s required)
├── .env.example                  # Docker Compose env vars example
├── .gitignore
└── README.md
```

---

## 🔄 Common Operations

### Tear down the cluster
```bash
terraform destroy
```

### Rebuild and redeploy the Next.js image
```bash
docker build -t stark-nextjs:latest ./nextjs-app
k3d image import stark-nextjs:latest -c stark-cluster
kubectl rollout restart deployment/nextjs -n stark
```

### Watch pod status
```bash
kubectl get pods -n stark -w
```

### View Next.js pod logs
```bash
kubectl logs -l app=nextjs -n stark --follow
```

### View Postgres logs
```bash
kubectl logs postgres-0 -n stark --follow
```

### Connect to the database directly
```bash
kubectl exec -it postgres-0 -n stark -- psql -U stark_user -d stark_db
```

---

## ⚙️ Auto-scaling

The HorizontalPodAutoscaler scales Next.js replicas automatically:

| Setting | Value |
|---------|-------|
| Minimum replicas | 3 |
| Maximum replicas | 10 |
| Scale-up trigger | CPU > 70% |

Check current scaling status:
```bash
kubectl get hpa -n stark
```

---

## 💻 Local Development (without Kubernetes)

For rapid frontend iteration, use Docker Compose instead:

```bash
cp .env.example .env
# edit .env with your credentials
docker compose up --build
```

App will be available at **http://localhost:3000**.

Or run natively:

```bash
cd nextjs-app
npm install
npm run dev
```

---

## 🔧 Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend / Backend | Next.js 15 (App Router) |
| Language | TypeScript |
| Database | PostgreSQL 15 |
| Container Runtime | Docker |
| Local Kubernetes | k3d (k3s in Docker) |
| Ingress / Load Balancer | Traefik (bundled with k3d) |
| Infrastructure as Code | Terraform |
| Auto-scaling | Kubernetes HPA |
