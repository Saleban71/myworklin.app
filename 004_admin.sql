-- ============================================================
-- WorkLink — Admin portal support + KPI views (PRD §18, §20)
-- ============================================================

-- helper: is the current user an admin?
create or replace function is_admin() returns boolean
language sql stable security definer as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- admins can read and update everything relevant to the portal
create policy "admin reads applications" on job_applications for select using (is_admin());
create policy "admin reads escrow" on escrow_transactions for select using (is_admin());
create policy "admin updates escrow" on escrow_transactions for update using (is_admin());
create policy "admin reads payouts" on payouts for select using (is_admin());
create policy "admin updates profiles" on profiles for update using (is_admin());
create policy "admin updates workers" on workers for update using (is_admin());
create policy "admin reads jobs" on jobs for select using (is_admin());
create policy "admin reads messages" on messages for select using (is_admin());

-- ---------- KPI view (PRD §20) ----------
create or replace view platform_kpis as
select
  (select count(*) from workers)                                        as registered_workers,
  (select count(*) from workers where verification <> 'phone')          as verified_workers,
  (select count(*) from employers)                                      as registered_employers,
  (select count(*) from jobs)                                           as jobs_posted,
  (select count(*) from jobs where status = 'completed')                as jobs_completed,
  (select coalesce(sum(amount_zmw), 0)
     from escrow_transactions where status = 'released')                as payment_volume_zmw,
  (select coalesce(avg(stars), 0)::numeric(3,2) from ratings)           as avg_rating,
  (select count(*) from jobs where status = 'disputed')                 as open_disputes;

-- expose only to admins
create or replace function get_platform_kpis()
returns setof platform_kpis language sql stable security definer as $$
  select * from platform_kpis where is_admin();
$$;

-- ---------- verification queue for the admin portal ----------
create or replace function verification_queue()
returns table (worker_id uuid, full_name text, phone text, nrc_number text,
               town text, verification verification_level, created_at timestamptz)
language sql stable security definer as $$
  select w.id, p.full_name, p.phone, p.nrc_number, p.town, w.verification, p.created_at
  from workers w join profiles p on p.id = w.id
  where is_admin()
    and p.nrc_number is not null
    and w.verification = 'phone'
  order by p.created_at;
$$;

-- ---------- admin action: approve NRC verification ----------
create or replace function approve_nrc(p_worker_id uuid)
returns void language plpgsql security definer as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  update profiles set nrc_verified = true where id = p_worker_id;
  update workers set verification = 'nrc' where id = p_worker_id and verification = 'phone';
  insert into notifications (profile_id, kind, title, body)
  values (p_worker_id, 'verification', 'NRC verified',
          'Your trust seal is now Level 2. Add face verification to reach Level 3.');
end;
$$;
