-- ─────────────────────────────────────────────
-- 02_seed.sql
-- Runs automatically after 01_schema.sql on
-- first Postgres startup.
--
-- IMPORTANT: Replace the password hash below
-- before deploying to production.
--
-- To generate a real bcrypt hash in Node.js:
--   const bcrypt = require('bcrypt');
--   console.log(await bcrypt.hash('your-password', 10));
-- ─────────────────────────────────────────────

INSERT INTO users (email, password, name, role, verified)
VALUES (
  'admin@stark.com',
  '$2b$10$REPLACEME.REPLACEME.REPLACEME.REPLACEME.REPLACEME.RE',  -- ← replace this hash
  'Stark Admin',
  'admin',
  TRUE
)
ON CONFLICT (email) DO NOTHING;
