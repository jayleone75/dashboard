# ExaGrid · Deal Command Center

A self-hosted, multi-deal sales tracker. Dashboard + a tab per opportunity, checkable next-steps, editable notes, and a running log — all synced across your devices via Supabase, gated by an access code. Same stack as the pet-sitting app: **GitHub → Cloudflare Pages → Supabase**.

---

## What's in here

```
exagrid-dashboard/
├─ index.html
├─ package.json
├─ vite.config.js
├─ .env.example
├─ supabase/
│  └─ schema.sql        ← run this in Supabase once (creates tables + seeds Ross)
└─ src/
   ├─ main.jsx
   ├─ App.jsx           ← auth + data layer + UI
   ├─ supabaseClient.js
   └─ styles.css
```

---

## Setup (about 20 minutes)

### 1. Supabase — the database
1. Create a project at supabase.com (free tier is plenty).
2. Open **SQL Editor → New query**, paste all of `supabase/schema.sql`, and **Run**. This creates the `users` and `deals` tables, the code-login function, row-level-security policies, turns on realtime, and seeds the Ross deal (plus empty Adventist & Lumentum).
3. **Change your access code:** in **Table Editor → users**, edit the seeded row and replace `CHANGE-ME-JAY` with a code only you know. Add a row per teammate later (e.g. Brad, Doug) with their own code.
4. Grab your keys from **Project Settings → API**: the **Project URL** and the **anon public** key.

### 2. GitHub — the code
1. Create a new repo and push this folder to it.
2. (Local dev, optional) copy `.env.example` to `.env.local`, fill in the two values, then `npm install` and `npm run dev`.

### 3. Cloudflare Pages — hosting at your domain
1. In the Cloudflare dashboard: **Workers & Pages → Create → Pages → Connect to Git**, pick the repo.
2. Build settings:
   - **Framework preset:** Vite
   - **Build command:** `npm run build`
   - **Build output directory:** `dist`
3. Add two **environment variables** (Production):
   - `VITE_SUPABASE_URL` = your Project URL
   - `VITE_SUPABASE_ANON_KEY` = your anon public key
4. Deploy. Then **Custom domains → Set up a domain** and add e.g. `exagrid-dashboard.jleoni.ai`. Since your DNS is already on Cloudflare, it wires the record automatically.

### 4. Use it
Open the subdomain on your phone or laptop, enter your access code, and go. Check a box on one device and it appears on the other within a second.

---

## How data flows
- Each deal is one row in `deals` (a JSONB `body` holding everything for that account).
- The app loads all deals on sign-in, subscribes to realtime changes, and writes the affected deal's row whenever you tick a box, add a step, edit notes (saved on blur), or add a log entry.
- Your login is just a code checked by the `login()` database function — no email, no magic link.

## Adding / editing deals
- **Add a teammate:** insert a row in `users` with their code, name, role.
- **Add a new deal:** insert a row in `deals` with a new `id`, the next `position`, and a `body` matching the shape of the Ross row (most fields can start as empty arrays). Or just tell Claude and it'll hand you the SQL.
- **Edit content:** anything you don't manage in-app (stakeholders, sizing, competitors) can be edited directly in the `body` JSON in Supabase, or ask Claude to regenerate it.

## Security note
This uses the pragmatic "internal tool" model — an access code plus an obscure subdomain, same as your pet-sitting app. The anon key can technically read/write the `deals` table (the `users` table is locked behind the login function so codes can't be dumped). For prospect notes that's a reasonable trade-off. If you ever want stronger guarantees, switch to Supabase Auth and tie the `deals` RLS policies to `auth.uid()`.

## Stack
React + Vite · Supabase (Postgres, realtime, RPC) · Cloudflare Pages. Cost: $0 beyond the domain you already own.
