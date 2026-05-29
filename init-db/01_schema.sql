-- ─────────────────────────────────────────────
-- 01_schema.sql
-- Runs automatically on first Postgres startup.
-- Creates all tables needed for auth.
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id           SERIAL PRIMARY KEY,
  email        VARCHAR(255) UNIQUE NOT NULL,
  password     VARCHAR(255)        NOT NULL,   -- always store bcrypt hashed, never plaintext
  name         VARCHAR(255),
  role         VARCHAR(50)         NOT NULL DEFAULT 'user',  -- 'user' | 'admin'
  verified     BOOLEAN             NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMP           NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMP           NOT NULL DEFAULT NOW()
);

-- Index on email for fast login lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- ─────────────────────────────────────────────
-- Automatically update updated_at on any row change
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- Sessions table — optional, use if you store
-- server-side sessions instead of JWTs
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
  id           SERIAL PRIMARY KEY,
  user_id      INTEGER      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token        VARCHAR(512) NOT NULL UNIQUE,
  expires_at   TIMESTAMP    NOT NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_token   ON sessions (token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id);
