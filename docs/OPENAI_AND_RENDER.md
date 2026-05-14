# OpenAI setup (Realtime)

1. **Account**: Sign in at [https://platform.openai.com](https://platform.openai.com).
2. **Billing**: Add a payment method and enable billing (Realtime is usage‑priced).
3. **API key**: **API keys** → **Create new secret key**. Copy it once; you will **not** show it in the mobile app — only on Render as `OPENAI_API_KEY`.
4. **Model**: In `.env` / Render use `OPENAI_REALTIME_MODEL` (for example `gpt-4o-realtime-preview` or another [Realtime model](https://platform.openai.com/docs/models) your key can access).
5. **Limits**: Set soft/hard usage limits under **Settings → Limits** to avoid surprises.
6. **Compliance**: Store only what you need; voice audio is sensitive — document retention in your privacy policy.

The gateway (`backend/scripts/realtime-gateway.cjs`) opens `wss://api.openai.com/v1/realtime?model=…` with `Authorization: Bearer <OPENAI_API_KEY>` and `OpenAI-Beta: realtime=v1`, then forwards frames between the app and OpenAI.

---

# Hosting on Render (PostgreSQL + Next.js + Gateway)

## 1. PostgreSQL

1. In Render: **New → PostgreSQL**.
2. Pick region/plan; create the database.
3. Copy the **Internal Database URL** (or **External** if you ever connect from outside Render).
4. Apply schema: connect with `psql` or Render shell and run `backend/sql/schema.sql`.

## 2. Next.js API (Web Service)

1. **New → Web Service**, connect the same Git repo as this project.
2. **Root directory**: `backend`.
3. **Runtime**: Node.
4. **Build command**: `npm install && npm run build`.
5. **Start command**: `npm run start` (uses `next start`; ensure `package.json` has this script).
6. **Environment** (minimum):
   - `DATABASE_URL` = Postgres URL from step 1 (Render can link the DB so this auto-fills).
   - `JWT_SECRET` = long random string.
   - `NODE_VERSION` = e.g. `22` (match local if you want).
7. Deploy; note the URL `https://your-api.onrender.com`. The Flutter app should use `--dart-define=API_BASE=https://your-api.onrender.com` (no trailing slash).

**Cold starts**: Free/starter Web Services sleep; first request can be slow. Paid instances stay warm.

## 3. Realtime gateway (second Web Service)

The gateway is a plain Node HTTP + WebSocket server (not Next). Run it as **another** Web Service:

1. **New → Web Service**, same repo, root `backend`.
2. **Build command**: `npm install` (no Next build required, but sharing `backend` with the API service is fine).
3. **Start command**: `node scripts/realtime-gateway.cjs`.
4. **Environment**:
   - `OPENAI_API_KEY`
   - `JWT_SECRET` (**must match** the Next.js service exactly).
   - `OPENAI_REALTIME_MODEL` (optional).
   - `PORT` is set by Render automatically; the script listens on `process.env.PORT`.
5. After deploy, use **`wss://your-gateway.onrender.com`** (Render terminates TLS; your app uses secure WebSocket).

Flutter:

```text
--dart-define=REALTIME_URL=wss://your-gateway.onrender.com
```

## 4. CORS / networking

- The **mobile app** talks to HTTPS and WSS directly; you usually **do not** need browser CORS for these native calls.
- Ensure the **JWT** used for REST is the same secret the gateway uses to verify `?token=`.

## 5. Health checks

- API: `GET https://your-api.onrender.com/api/health`
- Gateway HTTP GET returns a short plain body (Render health check can use `/`).

## 6. Migrations

For production, replace one-off `schema.sql` with a migration tool (Prisma, Drizzle, Flyway, etc.) when you evolve the schema.
