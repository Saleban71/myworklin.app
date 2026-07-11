# WorkLink

**Trusted work. Secure pay. A permanent digital work identity for Africa's informal workforce.**

WorkLink is a marketplace connecting Zambia's informal workers — bricklayers, electricians, cleaners, drivers, tailors — with households and businesses, through verified identities, AI-powered matching, escrow payments via mobile money, and a Digital Work Passport that workers own forever.

This repository contains the **Phase 1 codebase** from PRD v1.0:

| PRD feature | Where it lives |
|---|---|
| Phone + OTP registration (< 1 min) | `app/lib/screens/phone_auth_screen.dart` |
| Worker profiles, skills, availability, GPS | `supabase/migrations/001_schema.sql`, worker screens |
| AI Profile Generator (Claude API) | `supabase/functions/generate-profile/` |
| Job posting | `app/lib/screens/employer_screens.dart` |
| AI Matching Engine (9 ranking factors) | `match_workers()` in `supabase/migrations/003_functions.sql` |
| One-click hiring | `JobService.inviteWorker` |
| Secure in-app chat (realtime) | `app/lib/screens/chat_screen.dart` |
| Escrow payments (MTN MoMo / Airtel / Zamtel / bank) | `escrow_transactions` + `PaymentService` |
| Dual-confirmation completion | `job_applications` completion flags |
| Ratings → Trust Score | `on_rating_insert()` trigger |
| Digital Work Passport (auto-stamped on payout) | `on_escrow_released()` trigger |
| Verification levels L1–L5 + badges | `verification_level` enum, `badges` tables |
| Zambia Data Protection Act posture | Row Level Security in `002_rls.sql` |

## Tech stack (matches PRD §22)

| Layer | PRD spec | Implementation in this repo |
|---|---|---|
| **Frontend — mobile** | Flutter | `app/` — Dart, `supabase_flutter`, `geolocator`, `google_fonts` |
| **Frontend — web dashboard** | Web Dashboard | `web/` — React 18 + Vite + `@supabase/supabase-js` (employer/admin portal) |
| **Backend** | Supabase | `supabase/` — Postgres 15 + PostGIS, RLS, RPCs, triggers |
| **Database** | PostgreSQL | `supabase/migrations/*.sql` |
| **Authentication** | Supabase Auth | Phone OTP (app) · email magic link (dashboard) |
| **Storage** | Supabase Storage | Portfolio photos/certificates (`portfolio_items.media_url`) |
| **AI** | Claude API | `supabase/functions/generate-profile/` |
| **Payments** | MTN MoMo, Airtel, Zamtel, Bank | `supabase/functions/momo-collect/` + `momo-webhook/` (MTN pattern; replicate for Airtel/Zamtel) |
| **Notifications** | Firebase Cloud Messaging | `firebase_messaging` in `pubspec.yaml`; `notifications` table drives payloads |
| **Maps** | Google Maps Platform | GPS via PostGIS radius search; map UI is a Phase 2 add |
| **Analytics / Monitoring** | Firebase Analytics, Sentry | Add per environment at launch |

## Architecture

```
┌────────────────────────┐    ┌──────────────────────────┐
│   Flutter app (app/)   │    │  Web dashboard (web/)    │
│  workers & employers   │    │  React+Vite — employer   │
│  Android → iOS         │    │  analytics, admin portal │
└───────────┬────────────┘    └────────────┬─────────────┘
            │ supabase_flutter              │ supabase-js
┌───────────▼───────────────────────────────▼─────────────┐
│                        Supabase                          │
│  Postgres + PostGIS  ← schema, RLS, matching RPC,        │
│                        escrow/rating triggers, KPI RPCs  │
│  Edge Functions      ← generate-profile (Claude API),    │
│    (Deno)              momo-collect, momo-webhook        │
│  Auth                ← phone OTP (app), magic link (web) │
└───────────┬──────────────────────────────────────────────┘
            │ requesttopay + status verification
┌───────────▼────────────┐
│  MTN MoMo · Airtel     │  collection + disbursement APIs
│  Zamtel · Bank APIs    │
└────────────────────────┘
```

Key design decision: **money-critical logic lives in Postgres, not the client.** Releasing escrow fires a database trigger that stamps every hired worker's Work Passport, creates payouts, increments job counts, and sends notifications — atomically. Clients can never fabricate a work history entry (RLS allows read-only access to `work_passport_entries`).

## Getting started

### 1. Backend (Supabase)

```bash
npm i -g supabase
supabase login
supabase init          # if starting fresh
supabase link --project-ref YOUR_PROJECT_REF

# Apply schema, RLS, matching engine, seed data
supabase db push

# AI profile generator
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase functions deploy generate-profile
```

Enable **Phone Auth** in the Supabase dashboard (Auth → Providers → Phone) with an SMS provider (Twilio, MessageBird, or Vonage — Twilio has good Zambia coverage).

### 2. Mobile app (Flutter)

This repo ships `lib/` and `pubspec.yaml` only — the Android/iOS platform
folders are generated locally (they contain machine-specific config and
would bloat the repo). On a fresh clone:

```bash
cd app
flutter create . --org zm.co.worklink --platforms android,ios   # first time only
cp ../.env.example .env    # fill in SUPABASE_URL and SUPABASE_ANON_KEY
flutter pub get
flutter run
```

> **Note:** `pubspec.yaml` bundles `.env` as an asset, so the build will fail
> with a missing-asset error if you skip the `cp` step. For push notifications,
> also drop `google-services.json` into `app/android/app/` (it is gitignored).

### 3. Web dashboard

```bash
cd web
cp .env.example .env       # fill in VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm install
npm run dev                # http://localhost:5173
```

To grant a staff member admin access, set their profile role once:
`update profiles set role = 'admin' where phone = '+260...';`
The dashboard's KPI, verification-approval and payment views are gated by `is_admin()` in `004_admin.sql`.

#### Deploying the dashboard to Vercel

Deploy **from this Git repository**, never by uploading files or archives:

1. Push this repo to GitHub (see below).
2. In Vercel: **Add New → Project → Import** this repository.
3. **Set Root Directory to `web/`** — this is a monorepo, and without this
   Vercel looks for `package.json` at the repo root and the build fails.
4. Framework preset auto-detects as **Vite** (build `npm run build`,
   output `dist`). Leave the defaults.
5. Under **Environment Variables**, add:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
6. Deploy. Every subsequent `git push` redeploys automatically.

Finally, add your Vercel URL to Supabase **Auth → URL Configuration →
Redirect URLs**, or the magic-link sign-in will bounce back to localhost.

### 4. Mobile money (production)

The production payment path is already scaffolded:

```bash
supabase secrets set MTN_MOMO_SUBSCRIPTION_KEY=... MTN_MOMO_API_USER=... \
  MTN_MOMO_API_KEY=... MTN_MOMO_ENV=sandbox
supabase functions deploy momo-collect
supabase functions deploy momo-webhook --no-verify-jwt
```

Flow: the app calls `momo-collect` → escrow row created as `pending` → customer approves the `requesttopay` prompt on their phone → `momo-webhook` verifies the status **directly with MTN** (never trusting the callback body) and marks the escrow `funded`. Replicate the same two-function pattern for Airtel Money and Zamtel Kwacha. Before launch, switch `PaymentService.fundEscrow` in the Flutter app from the dev path (direct table write) to invoking `momo-collect`.

MoMo sandbox: https://momodeveloper.mtn.com (sandbox only supports EUR; ZMW is production)

## Repository layout

```
worklink/
├── app/                      # Flutter application
│   └── lib/
│       ├── core/             # theme (copper/green tokens), constants, supabase client
│       ├── models/           # typed models mapping to the schema
│       ├── services/         # auth, worker, jobs/matching, payments, chat
│       ├── screens/          # auth, employer flow, worker flow, chat
│       └── widgets/          # TrustSeal (copper verification mark), cards
├── web/                      # Web dashboard (React + Vite)
│   └── src/                  # login, KPI overview, verification queue,
│                             # jobs, escrow payments (PRD §15, §18, §20)
├── supabase/
│   ├── migrations/
│   │   ├── 001_schema.sql    # all Phase 1 tables + PostGIS
│   │   ├── 002_rls.sql       # row-level security
│   │   ├── 003_functions.sql # matching engine, escrow/rating triggers, seeds
│   │   └── 004_admin.sql     # admin policies, KPI view, verification queue
│   └── functions/
│       ├── generate-profile/ # Claude-powered AI profile generator
│       ├── momo-collect/     # MTN MoMo escrow collection (requesttopay)
│       └── momo-webhook/     # provider-verified funding confirmation
├── .env.example
└── README.md
```

## Roadmap (from PRD v1.0)

- **Phase 1 (this repo):** registration, profiles, job posting, AI matching, chat, mobile-money escrow, ratings, passport foundation
- **Phase 2:** Trust Score refinements, AI career assistant, multilingual UI (Bemba, Nyanja, Tonga, Lozi), analytics dashboards, dispute management, employer subscriptions
- **Phase 3:** marketplace, learning platform, micro-loans/insurance partnerships, government integration pilots (PACRA, NAPSA, NHIMA, ZRA, Smart Zambia)

## Security notes

- All tables have Row Level Security enabled; the anon key is safe to ship in the app.
- Escrow state transitions must move server-side before launch (see Mobile money section).
- Never commit `.env`, `google-services.json`, or provider API keys — `.gitignore` covers these.
- NRC numbers are stored for verification; before launch, review retention and encryption-at-rest obligations under the Zambia Data Protection Act (No. 3 of 2021) and consider hashing or vaulting NRC values.

## License

Proprietary — © WorkLink. All rights reserved.
