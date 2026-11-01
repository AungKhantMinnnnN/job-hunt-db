-- Runs once, on the first start of an empty volume.

create table jobs (
  slug             text primary key,           -- freehire's id for the posting
  title            text not null,
  company          text,
  company_slug     text,
  countries        text[],
  location         text,
  work_mode        text,
  seniority        text,
  category         text,
  employment_type  text,
  skills           text[],
  official_job_url text,                       -- the employer's own page: apply here
  freehire_url     text,
  posted_at        timestamptz,
  description      text,                       -- filled when a job is opened (get_job)
  raw              jsonb not null,             -- everything freehire sent, for later
  first_seen       timestamptz not null default now(),
  last_seen        timestamptz not null default now()
);

create table cvs (
  id        serial primary key,
  name      text not null unique,              -- "Base CV", or e.g. "2026-10-22 backend"
  file_path text not null,                     -- copy kept in this project's cvs/ folder
  job_slug  text references jobs,              -- the job a tailored CV was written for; null for the base CV
  added_at  timestamptz not null default now()
);

create table applications (
  id         serial primary key,
  job_slug   text not null unique references jobs,
  cv_id      int references cvs,
  status     text not null default 'applied'
             check (status in ('applied', 'interviewing', 'offer', 'rejected', 'withdrawn')),
  applied_at date not null default current_date,
  notes      text,
  updated_at timestamptz not null default now()
);

-- Takes a freehire tool result: {"jobs": [...]} from a search, or one job from get_job.
create function save_jobs(p jsonb) returns int language sql as $$
  with rows as (
    select j from jsonb_array_elements(
      case when p ? 'jobs' then p->'jobs' else jsonb_build_array(p) end) j
    where j ? 'slug'
  ), saved as (
    insert into jobs (slug, title, company, company_slug, countries, location, work_mode,
                      seniority, category, employment_type, skills, official_job_url,
                      freehire_url, posted_at, description, raw)
    select j->>'slug', j->>'title', j->>'company', j->>'company_slug',
           case when j ? 'countries' then array(select jsonb_array_elements_text(j->'countries')) end,
           j->>'location', j->>'work_mode', j->>'seniority', j->>'category',
           j->>'employment_type',
           case when j ? 'skills' then array(select jsonb_array_elements_text(j->'skills')) end,
           j->>'official_job_url', j->>'url', (j->>'posted_at')::timestamptz,
           j->>'description', j
    from rows
    on conflict (slug) do update set  -- a field only changes when the new result has it
      title = coalesce(excluded.title, jobs.title),
      company = coalesce(excluded.company, jobs.company),
      company_slug = coalesce(excluded.company_slug, jobs.company_slug),
      countries = coalesce(excluded.countries, jobs.countries),
      location = coalesce(excluded.location, jobs.location),
      work_mode = coalesce(excluded.work_mode, jobs.work_mode),
      seniority = coalesce(excluded.seniority, jobs.seniority),
      category = coalesce(excluded.category, jobs.category),
      employment_type = coalesce(excluded.employment_type, jobs.employment_type),
      skills = coalesce(excluded.skills, jobs.skills),
      official_job_url = coalesce(excluded.official_job_url, jobs.official_job_url),
      freehire_url = coalesce(excluded.freehire_url, jobs.freehire_url),
      posted_at = coalesce(excluded.posted_at, jobs.posted_at),
      description = coalesce(excluded.description, jobs.description),
      raw = jobs.raw || excluded.raw,
      last_seen = now()
    returning 1
  )
  select count(*)::int from saved;
$$;

-- One row per job and country, with a readable country name, sorted by place.
create or replace view jobs_by_location as
select case c when 'sg' then 'Singapore' when 'my' then 'Malaysia' when 'th' then 'Thailand'
              when 'id' then 'Indonesia' when 'ph' then 'Philippines' when 'hk' then 'Hong Kong'
              else upper(c) end as country,
       location as city, title, company, work_mode, posted_at, official_job_url, slug, last_seen
from jobs, unnest(coalesce(nullif(countries, '{}'), '{??}')) c
order by country, city, posted_at desc;
