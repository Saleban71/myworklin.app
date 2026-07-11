-- ============================================================
-- WorkLink — Initial schema (PRD v1.0, Phase 1)
-- Postgres 15 / Supabase
-- ============================================================

create extension if not exists "postgis";
create extension if not exists "pgcrypto";

-- ---------- enums ----------
create type user_role as enum ('worker', 'employer', 'admin');

create type availability_status as enum (
  'available_now', 'available_today', 'available_tomorrow',
  'available_this_week', 'busy', 'offline'
);

create type verification_level as enum ('phone', 'nrc', 'face', 'reference', 'top_rated');

create type job_status as enum ('draft', 'open', 'matching', 'in_progress', 'completed', 'cancelled', 'disputed');

create type application_status as enum ('invited', 'applied', 'accepted', 'declined', 'withdrawn');

create type escrow_status as enum ('pending', 'funded', 'released', 'refunded', 'disputed');

create type payment_provider as enum ('mtn_momo', 'airtel_money', 'zamtel_money', 'bank_transfer');

-- ---------- profiles (1:1 with auth.users) ----------
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role user_role not null default 'worker',
  full_name text not null,
  phone text unique not null,
  nrc_number text unique,                    -- National Registration Card
  nrc_verified boolean not null default false,
  face_verified boolean not null default false,
  preferred_language text not null default 'en',  -- en, bem, nya, ton, loz
  avatar_url text,
  location geography(point, 4326),
  town text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- skills catalogue ----------
create table skills (
  id serial primary key,
  slug text unique not null,
  name text not null,
  category text not null
);

-- ---------- workers ----------
create table workers (
  id uuid primary key references profiles (id) on delete cascade,
  bio text,                                   -- AI-generated professional summary
  years_experience int not null default 0,
  hourly_rate_zmw numeric(10,2),
  daily_rate_zmw numeric(10,2),
  availability availability_status not null default 'offline',
  verification verification_level not null default 'phone',
  trust_score int not null default 0 check (trust_score between 0 and 100),
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  jobs_completed int not null default 0,
  repeat_employer_count int not null default 0,
  avg_response_seconds int,                   -- for AI matching
  languages text[] not null default '{}',
  search_document tsvector
);

create table worker_skills (
  worker_id uuid references workers (id) on delete cascade,
  skill_id int references skills (id) on delete cascade,
  primary key (worker_id, skill_id)
);

create table portfolio_items (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references workers (id) on delete cascade,
  media_url text not null,
  media_type text not null check (media_type in ('photo', 'video', 'certificate')),
  caption text,
  created_at timestamptz not null default now()
);

-- ---------- employers ----------
create table employers (
  id uuid primary key references profiles (id) on delete cascade,
  company_name text,
  employer_type text check (employer_type in
    ('household','sme','construction','retail','transport','ngo','government')),
  rating_avg numeric(3,2) not null default 0,
  jobs_posted int not null default 0
);

-- ---------- jobs ----------
create table jobs (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references employers (id) on delete cascade,
  title text not null,
  description text,
  skill_id int not null references skills (id),
  workers_needed int not null default 1 check (workers_needed > 0),
  location geography(point, 4326) not null,
  town text not null,
  start_date date not null,
  duration_days int not null default 1,
  budget_zmw numeric(12,2) not null,
  status job_status not null default 'open',
  deadline timestamptz,
  created_at timestamptz not null default now()
);

create index jobs_location_idx on jobs using gist (location);
create index jobs_status_idx on jobs (status);

-- ---------- applications / hires ----------
create table job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs (id) on delete cascade,
  worker_id uuid not null references workers (id) on delete cascade,
  status application_status not null default 'invited',
  match_score numeric(6,2),                   -- AI matching score at invite time
  worker_marked_complete boolean not null default false,
  employer_confirmed_complete boolean not null default false,
  created_at timestamptz not null default now(),
  unique (job_id, worker_id)
);

-- ---------- escrow ----------
create table escrow_transactions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs (id) on delete cascade,
  employer_id uuid not null references employers (id),
  amount_zmw numeric(12,2) not null,
  provider payment_provider not null,
  provider_reference text,                    -- MoMo / Airtel / bank txn id
  status escrow_status not null default 'pending',
  funded_at timestamptz,
  released_at timestamptz,
  created_at timestamptz not null default now()
);

create table payouts (
  id uuid primary key default gen_random_uuid(),
  escrow_id uuid not null references escrow_transactions (id),
  worker_id uuid not null references workers (id),
  amount_zmw numeric(12,2) not null,
  provider payment_provider not null,
  provider_reference text,
  paid_at timestamptz
);

-- ---------- chat ----------
create table conversations (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references jobs (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table conversation_members (
  conversation_id uuid references conversations (id) on delete cascade,
  profile_id uuid references profiles (id) on delete cascade,
  primary key (conversation_id, profile_id)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations (id) on delete cascade,
  sender_id uuid not null references profiles (id),
  body text,
  media_url text,
  lat double precision,
  lng double precision,
  created_at timestamptz not null default now()
);

create index messages_conversation_idx on messages (conversation_id, created_at);

-- ---------- ratings ----------
create table ratings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs (id) on delete cascade,
  rater_id uuid not null references profiles (id),
  ratee_id uuid not null references profiles (id),
  stars int not null check (stars between 1 and 5),
  quality int check (quality between 1 and 5),
  punctuality int check (punctuality between 1 and 5),
  communication int check (communication between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (job_id, rater_id, ratee_id)
);

-- ---------- digital work passport ----------
create table work_passport_entries (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references workers (id) on delete cascade,
  job_id uuid not null references jobs (id),
  employer_name text not null,
  job_title text not null,
  town text,
  duration_days int,
  amount_paid_zmw numeric(12,2),
  stars int,
  skills_used text[],
  completed_at timestamptz not null default now()
);

create index passport_worker_idx on work_passport_entries (worker_id, completed_at desc);

-- ---------- badges ----------
create table badges (
  id serial primary key,
  slug text unique not null,
  name text not null,
  description text
);

create table worker_badges (
  worker_id uuid references workers (id) on delete cascade,
  badge_id int references badges (id) on delete cascade,
  awarded_at timestamptz not null default now(),
  primary key (worker_id, badge_id)
);

-- ---------- notifications ----------
create table notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  kind text not null,          -- new_job, payment_received, review, reminder, loan_eligible
  title text not null,
  body text,
  data jsonb not null default '{}',
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- updated_at trigger ----------
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger profiles_updated before update on profiles
  for each row execute function set_updated_at();
