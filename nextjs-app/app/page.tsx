import styles from "./page.module.css";

const stack = [
  {
    icon: "▲",
    name: "Next.js 14",
    desc: "React framework with App Router, SSR, and standalone output",
    color: "#e8ff47",
  },
  {
    icon: "🐳",
    name: "Docker",
    desc: "Multi-stage build producing a lean Alpine-based production image",
    color: "#60a5fa",
  },
  {
    icon: "◈",
    name: "Terraform",
    desc: "Infrastructure as Code — network, image build, and containers declared in HCL",
    color: "#a78bfa",
  },
  {
    icon: "🐘",
    name: "PostgreSQL 15",
    desc: "Relational database running in its own container on the private network",
    color: "#4ade80",
  },
];

const infra = [
  { label: "Network", value: "stark_network", note: "Private bridge" },
  { label: "DB container", value: "db_service", note: "postgres:15" },
  { label: "Web container", value: "stark_web", note: "Port 3000" },
  { label: "IaC tool", value: "Terraform", note: "kreuzwerker/docker" },
];

export default function Home() {
  return (
    <main className={styles.main}>
      {/* ── Hero ── */}
      <section className={styles.hero}>
        <div className={styles.heroBadge}>
          <span className={styles.dot} />
          Running in Docker
        </div>
        <h1 className={styles.title}>
          stark<span className={styles.accent}>.</span>app
        </h1>
        <p className={styles.subtitle}>
          A full-stack containerised application scaffolded with{" "}
          <strong>Terraform</strong> and deployed via <strong>Docker Desktop</strong>.
          Built to demonstrate Infrastructure-as-Code skills to employers.
        </p>
        <div className={styles.heroCta}>
          <a
            href="https://github.com/TaylorWilliams90/stark-app"
            target="_blank"
            rel="noopener noreferrer"
            className={styles.btnPrimary}
          >
            View on GitHub →
          </a>
          <a href="#stack" className={styles.btnGhost}>
            See the stack ↓
          </a>
        </div>
      </section>

      {/* ── Infrastructure snapshot ── */}
      <section className={styles.infraBar}>
        {infra.map((item) => (
          <div key={item.label} className={styles.infraItem}>
            <span className={styles.infraLabel}>{item.label}</span>
            <code className={styles.infraValue}>{item.value}</code>
            <span className={styles.infraNote}>{item.note}</span>
          </div>
        ))}
      </section>

      {/* ── Stack cards ── */}
      <section id="stack" className={styles.section}>
        <h2 className={styles.sectionTitle}>
          <span className={styles.sectionLine} /> Tech Stack
        </h2>
        <div className={styles.cards}>
          {stack.map((item) => (
            <div key={item.name} className={styles.card}>
              <span className={styles.cardIcon} style={{ color: item.color }}>
                {item.icon}
              </span>
              <h3 className={styles.cardName}>{item.name}</h3>
              <p className={styles.cardDesc}>{item.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Architecture diagram (text-based) ── */}
      <section className={styles.section}>
        <h2 className={styles.sectionTitle}>
          <span className={styles.sectionLine} /> Architecture
        </h2>
        <div className={styles.diagram}>
          <pre className={styles.pre}>{`
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
          `.trim()}</pre>
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className={styles.footer}>
        <p>
          Built with <span className={styles.accent}>♥</span> using Next.js ·
          Docker · Terraform
        </p>
      </footer>
    </main>
  );
}