-- ============================================================
-- WorkLink — Matching engine, escrow lifecycle, reputation
-- ============================================================

-- ---------- AI matching (PRD §6: distance, skills, ratings,
-- availability, past performance, repeat engagement, price,
-- response speed, verification) ----------
create or replace function match_workers(p_job_id uuid, p_limit int default 20)
returns table (
  worker_id uuid,
  full_name text,
  match_score numeric,
  distance_km numeric,
  rating_avg numeric,
  daily_rate_zmw numeric,
  availability availability_status,
  verification verification_level,
  jobs_completed int
) language sql stable as $$
  with job as (select * from jobs where id = p_job_id)
  select
    w.id,
    p.full_name,
    round((
      -- skills match: 30
      case when exists (select 1 from worker_skills ws
                        where ws.worker_id = w.id and ws.skill_id = job.skill_id)
           then 30 else 0 end
      -- distance: up to 20 (decays 1pt/km)
      + greatest(0, 20 - st_distance(p.location, job.location) / 1000.0)
      -- rating: up to 20
      + w.rating_avg * 4
      -- availability: up to 12
      + case w.availability
          when 'available_now' then 12
          when 'available_today' then 9
          when 'available_tomorrow' then 6
          when 'available_this_week' then 3
          else 0 end
      -- verification: up to 12.5
      + case w.verification
          when 'top_rated' then 12.5
          when 'reference' then 10
          when 'face' then 7.5
          when 'nrc' then 5
          else 2.5 end
      -- repeat engagement: up to ~8
      + least(8, w.repeat_employer_count / 10.0)
      -- price fit: up to 5 when within budget/day
      + case when w.daily_rate_zmw is not null
                  and w.daily_rate_zmw * job.duration_days * job.workers_needed <= job.budget_zmw * 1.1
             then 5 else 0 end
      -- response speed: up to 5
      + case when w.avg_response_seconds is null then 0
             when w.avg_response_seconds < 300 then 5
             when w.avg_response_seconds < 1800 then 3
             else 1 end
    )::numeric, 2) as match_score,
    round((st_distance(p.location, job.location) / 1000.0)::numeric, 1) as distance_km,
    w.rating_avg, w.daily_rate_zmw, w.availability, w.verification, w.jobs_completed
  from workers w
  join profiles p on p.id = w.id, job
  where p.location is not null
    and w.availability <> 'offline'
    and st_dwithin(p.location, job.location, 50000)   -- 50 km max radius (PRD)
  order by match_score desc
  limit p_limit;
$$;

-- ---------- completion check ----------
create or replace function job_is_complete(p_job_id uuid) returns boolean
language sql stable as $$
  select count(*) > 0 and bool_and(worker_marked_complete and employer_confirmed_complete)
  from job_applications
  where job_id = p_job_id and status = 'accepted';
$$;

-- ---------- escrow release: stamp the Digital Work Passport ----------
create or replace function on_escrow_released() returns trigger
language plpgsql security definer as $$
declare
  v_job jobs%rowtype;
  v_employer_name text;
  v_skill text;
  v_app record;
  v_share numeric;
  v_worker_count int;
begin
  if new.status = 'released' and old.status <> 'released' then
    select * into v_job from jobs where id = new.job_id;
    select coalesce(e.company_name, p.full_name) into v_employer_name
      from employers e join profiles p on p.id = e.id where e.id = v_job.employer_id;
    select name into v_skill from skills where id = v_job.skill_id;

    select count(*) into v_worker_count
      from job_applications where job_id = new.job_id and status = 'accepted';
    v_share := round(new.amount_zmw / greatest(v_worker_count, 1), 2);

    for v_app in
      select worker_id from job_applications
      where job_id = new.job_id and status = 'accepted'
    loop
      insert into work_passport_entries
        (worker_id, job_id, employer_name, job_title, town,
         duration_days, amount_paid_zmw, skills_used, completed_at)
      values
        (v_app.worker_id, v_job.id, v_employer_name, v_job.title, v_job.town,
         v_job.duration_days, v_share, array[v_skill], now());

      update workers set jobs_completed = jobs_completed + 1 where id = v_app.worker_id;

      insert into payouts (escrow_id, worker_id, amount_zmw, provider)
      values (new.id, v_app.worker_id, v_share, new.provider);

      insert into notifications (profile_id, kind, title, body, data)
      values (v_app.worker_id, 'payment_received', 'Payment received',
              format('ZMW %s released for "%s"', v_share, v_job.title),
              jsonb_build_object('job_id', v_job.id));
    end loop;

    update jobs set status = 'completed' where id = v_job.id;
  end if;
  return new;
end;
$$;

create trigger escrow_released after update on escrow_transactions
  for each row execute function on_escrow_released();

-- ---------- rating aggregation + trust score ----------
create or replace function on_rating_insert() returns trigger
language plpgsql security definer as $$
begin
  update workers w set
    rating_avg = sub.avg_stars,
    rating_count = sub.n,
    trust_score = least(100, round(
        sub.avg_stars * 12                                  -- up to 60
      + least(20, w.jobs_completed)                         -- up to 20
      + case w.verification when 'top_rated' then 20 when 'reference' then 16
             when 'face' then 12 when 'nrc' then 8 else 4 end
    ))
  from (select avg(stars)::numeric(3,2) avg_stars, count(*) n
        from ratings where ratee_id = new.ratee_id) sub
  where w.id = new.ratee_id;

  -- also stamp the star onto the matching passport entry
  update work_passport_entries
     set stars = new.stars
   where job_id = new.job_id and worker_id = new.ratee_id;

  return new;
end;
$$;

create trigger rating_inserted after insert on ratings
  for each row execute function on_rating_insert();

-- ============================================================
-- Seed data: skills catalogue (PRD §6) + badges (PRD §7)
-- ============================================================
insert into skills (slug, name, category) values
  ('bricklaying','Bricklaying','Construction'),
  ('construction','General construction','Construction'),
  ('plumbing','Plumbing','Construction'),
  ('electrical','Electrical','Construction'),
  ('painting','Painting','Construction'),
  ('welding','Welding','Construction'),
  ('carpentry','Carpentry','Construction'),
  ('cleaning','Cleaning','Services'),
  ('domestic_work','Domestic work','Services'),
  ('security','Security','Services'),
  ('driving','Driving','Transport'),
  ('agriculture','Agriculture','Agriculture'),
  ('mechanics','Mechanics','Technical'),
  ('tailoring','Tailoring','Crafts'),
  ('beauty','Beauty services','Services'),
  ('ict_support','ICT support','Technical'),
  ('food_services','Food services','Services'),
  ('moving','Moving services','Transport'),
  ('general_labour','General labour','General');

insert into badges (slug, name, description) values
  ('verified_worker','Verified Worker','NRC and face verification complete'),
  ('fast_responder','Fast Responder','Median response under 5 minutes'),
  ('top_rated','Top Rated','4.8+ average over 25+ jobs'),
  ('jobs_100','100 Jobs Completed','Completed 100 jobs on WorkLink'),
  ('excellent_quality','Excellent Quality','Consistently 5-star quality scores'),
  ('repeat_favourite','Repeat Employer Favourite','High repeat-hire rate');
