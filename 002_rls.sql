-- ============================================================
-- WorkLink — Row Level Security
-- Principle: workers own their data; employers see public worker
-- profiles; job parties see their shared job, chat and escrow.
-- ============================================================

alter table profiles enable row level security;
alter table workers enable row level security;
alter table worker_skills enable row level security;
alter table portfolio_items enable row level security;
alter table employers enable row level security;
alter table jobs enable row level security;
alter table job_applications enable row level security;
alter table escrow_transactions enable row level security;
alter table payouts enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table ratings enable row level security;
alter table work_passport_entries enable row level security;
alter table worker_badges enable row level security;
alter table notifications enable row level security;
alter table skills enable row level security;
alter table badges enable row level security;

-- catalogue tables: readable by everyone
create policy "skills readable" on skills for select using (true);
create policy "badges readable" on badges for select using (true);

-- profiles: public basic read, self write
create policy "profiles readable" on profiles for select using (true);
create policy "profiles self insert" on profiles for insert with check (auth.uid() = id);
create policy "profiles self update" on profiles for update using (auth.uid() = id);

-- workers: public read (marketplace), self write
create policy "workers readable" on workers for select using (true);
create policy "workers self write" on workers for insert with check (auth.uid() = id);
create policy "workers self update" on workers for update using (auth.uid() = id);

create policy "worker_skills readable" on worker_skills for select using (true);
create policy "worker_skills self manage" on worker_skills
  for all using (auth.uid() = worker_id) with check (auth.uid() = worker_id);

create policy "portfolio readable" on portfolio_items for select using (true);
create policy "portfolio self manage" on portfolio_items
  for all using (auth.uid() = worker_id) with check (auth.uid() = worker_id);

-- employers
create policy "employers readable" on employers for select using (true);
create policy "employers self write" on employers for insert with check (auth.uid() = id);
create policy "employers self update" on employers for update using (auth.uid() = id);

-- jobs: open jobs visible to all; employer manages own
create policy "open jobs readable" on jobs for select
  using (status in ('open','matching') or employer_id = auth.uid()
         or exists (select 1 from job_applications a
                    where a.job_id = jobs.id and a.worker_id = auth.uid()));
create policy "employer creates job" on jobs for insert with check (employer_id = auth.uid());
create policy "employer updates job" on jobs for update using (employer_id = auth.uid());

-- applications: visible to the worker and the job's employer
create policy "application parties read" on job_applications for select
  using (worker_id = auth.uid()
         or exists (select 1 from jobs j where j.id = job_id and j.employer_id = auth.uid()));
create policy "employer invites" on job_applications for insert
  with check (exists (select 1 from jobs j where j.id = job_id and j.employer_id = auth.uid()));
create policy "parties update application" on job_applications for update
  using (worker_id = auth.uid()
         or exists (select 1 from jobs j where j.id = job_id and j.employer_id = auth.uid()));

-- escrow: parties only; state transitions are done by edge functions
-- with the service role, never directly by clients.
create policy "escrow parties read" on escrow_transactions for select
  using (employer_id = auth.uid()
         or exists (select 1 from job_applications a
                    where a.job_id = escrow_transactions.job_id and a.worker_id = auth.uid()));

create policy "payout worker reads" on payouts for select using (worker_id = auth.uid());

-- chat
create policy "member reads conversation" on conversations for select
  using (exists (select 1 from conversation_members m
                 where m.conversation_id = id and m.profile_id = auth.uid()));
create policy "members readable to members" on conversation_members for select
  using (exists (select 1 from conversation_members m
                 where m.conversation_id = conversation_members.conversation_id
                   and m.profile_id = auth.uid()));
create policy "member reads messages" on messages for select
  using (exists (select 1 from conversation_members m
                 where m.conversation_id = messages.conversation_id and m.profile_id = auth.uid()));
create policy "member sends message" on messages for insert
  with check (sender_id = auth.uid()
    and exists (select 1 from conversation_members m
                where m.conversation_id = messages.conversation_id and m.profile_id = auth.uid()));

-- ratings: parties of the job may rate
create policy "ratings readable" on ratings for select using (true);
create policy "job party rates" on ratings for insert
  with check (rater_id = auth.uid()
    and exists (select 1 from jobs j
                left join job_applications a on a.job_id = j.id
                where j.id = ratings.job_id
                  and (j.employer_id = auth.uid() or a.worker_id = auth.uid())));

-- passport: public read (its whole value is verifiability); writes via triggers only
create policy "passport readable" on work_passport_entries for select using (true);

create policy "worker badges readable" on worker_badges for select using (true);

-- notifications: self only
create policy "own notifications" on notifications for select using (profile_id = auth.uid());
create policy "own notifications update" on notifications for update using (profile_id = auth.uid());
