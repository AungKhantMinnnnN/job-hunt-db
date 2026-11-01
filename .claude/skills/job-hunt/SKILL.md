---
name: job-hunt
description: Search JobStreet (through the freehire MCP tools) for jobs that match the user's base CV, meaning their experience, education and skills, plus their search query, in the country set in applicant.md. Use when the user asks to find jobs, look for roles, check who is hiring, or apply to a posting.
---

# Job hunt (JobStreet, matched to the base CV)

Tools come from the `freehire` MCP server: `search_jobs`, `get_job`, `similar_jobs`,
`check_jobs_open`, `search_companies`, `get_company`, `salary_stats`, `job_market_stats`.
Every search uses `sources: ["jobstreet"]`. No other boards. All paths below are relative to
the project folder (the repo root, where Claude Code runs).

## 0. First run

If `applicant.md` is missing, copy `applicant.example.md` to `applicant.md` and ask the
user to fill in the "Search" and "Ask once" sections. If there's no `Base CV` row (step 1),
set the base CV up:
1. Read the user's CV (they put the PDF or Word file in `cvs/`).
2. Copy `cvs/base-cv.example.html` to `cvs/base-cv.html` and replace the placeholder content
   with the CV's content, word for word. Keep the layout and add nothing.
3. Run `./render_cv.sh cvs/base-cv.html`, read the PDF back, and compare it with their CV.
4. `insert into cvs (name, file_path) values ('Base CV', 'cvs/base-cv.pdf');`

## 1. Read the base CV (every run)

The base CV is the `cvs` row named `Base CV`:

    docker exec -i job-hunt-db psql -U jobs -d jobs -qAt -c "select file_path from cvs where name = 'Base CV'"

Read that file and note:
- **Years of experience**, counted from the job dates to today, not copied from the summary.
- **Highest education** and whether it's finished (graduation year vs today).
- **Core stack** (what they've used at work) vs **side skills** (projects, "fundamentals").
- **Location and work rights.** These come from `applicant.md`: the country to search, and
  whether the user needs visa or work-pass sponsorship there.

## 2. Turn the query into a search

- `sources: ["jobstreet"]`, `countries: [<the search country from applicant.md, default "sg">]`, `posted_within_days: 30`, `limit: 25`.
- Put technologies in `skills` as freehire tags (`csharp`, `dotnet`, `sql-server`,
  `postgresql`, `docker`, `kubernetes`, `aws`, `python`, `typescript`, …), taken from the
  user's query. If the query names no technology, use the CV's core stack. Don't put tech
  names in `query`: `.net` there also matches "network".
- Use `query` only for the kind of role, e.g. `title:backend OR title:"software engineer"`.
- Don't filter on `seniority`. Most JobStreet postings don't have one, so you would lose them.
- `skills` matches ANY tag listed, so expect noise. Step 3 is where the matching happens.
- If `ignored_params` comes back, fix that filter and search again.

## 3. Screen against the CV

Drop jobs whose title or skills are plainly off-target. Call `get_job` on the rest (up to
about 15). Its `requirements` list marks each line `required` or `preferred`. Keep a job only if it
passes all of these:

- **Experience**: the years it requires are no more than the CV's years + 1. Reject a role
  aimed at interns or fresh graduates unless the user asks for one. Reject lead/principal/manager
  roles unless the CV shows that level.
- **Education**: the level it requires is no higher than the CV's. A *preferred* degree never
  rules a job out. A degree "in progress" or graduating this year counts as held.
- **Skills**: the CV covers most of the *required* technical lines. Missing *preferred*
  items are gaps, not reasons to reject.
- **Work rights**: if `applicant.md` says the user needs sponsorship, reject postings limited
  to citizens or permanent residents ("Singaporeans only", "Malaysians only", "citizens/PR
  only"…). A posting that mentions visa or work-pass sponsorship is a plus.

## 4. Show the results

Ordered best first. For each job: **Strong** or **Good** fit, title, company, posted date,
one line on why it fits (experience, education, matching skills), its gaps, and the
JobStreet ad link. freehire's tools leave that link out, so get it for the whole shortlist in
one call (it saves nothing; jobs are saved only when an application is logged):

    ./job_url.sh <slug> <slug> …

If a slug prints nothing, show freehire's `url` for that job instead. Mark `reality: stale` jobs "may be stale" and run `check_jobs_open` on
the shortlist. End with one line counting what was rejected and why, e.g.
"Rejected 9: 4 need 7+ yrs, 3 citizens/PR only, 2 off-stack."

If fewer than 5 jobs match, offer to run the same search in JobStreet's other markets:
`sg`, `my`, `hk`, `th`, `id`, `ph`, without the one already searched.

## Applying to a job

Use this when the user says "apply to <job>".

**1. Pick the job.** Use the slug from this conversation's search results; if it isn't
there, find it with `search_jobs`. If more than one job matches, ask which. Call `get_job`
for the description. Run `check_jobs_open` on it, and stop if the job is closed. Get the
JobStreet link with `./job_url.sh <slug>`. Don't save the job yet.

**2. Tailor the CV.** Copy `cvs/base-cv.html`, the editable source of the base CV, to
`cvs/<YYYY-MM-DD>-<company>-<title>.html`, using lowercase-hyphenated names. Edit only the copy:
- Rewrite the Professional Summary toward this job, using the posting's own words wherever
  the CV backs them up.
- Reorder the skills, projects and bullets so the ones the job asks for come first. Cut or
  shorten what's irrelevant.
- Use the posting's wording for things the CV already shows, e.g. "ASP.NET Core" for "ASP.NET Core Web API".
- **Never add** a skill, tool, employer, title, date, degree, number or achievement that the
  base CV doesn't show. Gaps stay gaps; mention them to the user instead.
- **No borrowed traits.** Don't copy the posting's adjectives or soft claims ("secure",
  "fast learner", "full life cycle", "high quality", "leadership"…) unless the base CV
  already says them. Every phrase in the new summary must trace to a specific line of the
  base CV.
- Keep it to 2 pages and keep the layout (it is ATS-safe: one column, real text).

Check the changes before going on:

    diff <(sed 's/<[^>]*>//g' cvs/base-cv.html) <(sed 's/<[^>]*>//g' cvs/<name>.html)

For each changed line, name the base-CV line that backs it up. Remove anything that has none.

Render it with `./render_cv.sh cvs/<name>.html`, which writes `cvs/<name>.pdf`. Read the PDF
back to check it is at most 2 pages and nothing broke. Tell the user, in a few bullets, what
changed and which gaps are left.

**3. Don't record anything yet.** The PDF stays in `cvs/`; it goes into the database in step 7.

**4. Open the application in Claude in Chrome** (the user's real Chrome, where they are
signed in to JobStreet). Load the browser tools with ToolSearch and check
`list_connected_browsers`. If none is connected, stop there: tell the user to install or
turn on the Claude in Chrome extension, and say the CV is ready at `cvs/<name>.pdf`. Don't
switch to another browser, because only Claude in Chrome can attach the CV file.

In a new tab, open the JobStreet link and click **Apply / Quick apply**. That only opens the
form; it doesn't send anything. If JobStreet asks the user to sign in, stop and let them do
it. Never type passwords or create accounts.

**5. Fill the form.**
- **CV**: attach `cvs/<name>.pdf` with `file_upload` on the file input. Don't click the
  upload button, which opens a picker you can't see. If JobStreet offers a stored CV, pick
  "upload a new one" instead.
- **Cover letter**: if there's a box, write a short one (about 150 words) from the tailored
  CV and the posting, held to the same never-add rule.
- **Questions and personal details**: answer from `applicant.md`. If a question isn't
  covered there, or the field is empty, ask the user. Never guess salary, notice period,
  work-pass status or nationality. Save each new answer under "Other answers given".
- **JobStreet profile pages** (e.g. "update your profile"): only change what the form needs
  for this application.

**6. Stop before the final Submit button.** Take a screenshot and list for the user what was
filled in, field by field. The user reviews it and clicks Submit themselves. Click Submit for
them only if they say so in chat for this particular application. An earlier "yes" doesn't carry over.

**7. Log it once the user says it was sent.** Save the job, then the CV, then the application:

    ./save_job.sh <slug>

    insert into cvs (name, file_path, job_slug) values ('<date> <company> <title>', 'cvs/<name>.pdf', '<slug>');
    insert into applications (job_slug, cv_id) values ('<slug>', (select id from cvs where name = '<date> <company> <title>'));

For a job that isn't on freehire (e.g. an employer's own careers site), insert the `jobs` row
by hand instead: slug, title, company, location, official_job_url, description, and
`raw = '{"source":"manual"}'`.

If they don't send it, write nothing to the database. The tailored PDF stays in `cvs/`.

## Database (Postgres in Docker)

The database holds only jobs the user applied to. Search results are not saved; a job is
added with `./save_job.sh <slug>` when its application is logged. If the container is down,
start it with `docker compose up -d` in the project folder. Run SQL with:

    docker exec -i job-hunt-db psql -U jobs -d jobs -c "<sql>"

Tables (see `schema.sql`):
- `jobs`: slug, title, company, countries[], location, work_mode, seniority, skills[],
  official_job_url, posted_at, description (only after `get_job`), first_seen, last_seen.
- `cvs`: id, name, file_path (relative to the project folder), job_slug (the job a tailored
  CV was written for; empty for the base CV).
- `jobs_by_location` (view): country (full name), city, title, company, work_mode,
  posted_at, official_job_url, slug, last_seen, sorted by country then city. Use it for
  any "by location" or "jobs in <country/city>" question, e.g.
  `select * from jobs_by_location where country = 'Malaysia' and city ilike '%penang%'`.
- `applications`: job_slug → jobs, cv_id → cvs, status (applied / interviewing / offer /
  rejected / withdrawn), applied_at, notes.

When the user says they applied to a job:
1. Make sure the job is in `jobs` (run `./save_job.sh <slug>` if not).
2. Ask which CV they used. If it's the base CV, use the `Base CV` row. If it's a tailored
   one, copy the file into `cvs/` with a dated name, e.g. `2026-10-22-backend.pdf`, and insert
   a `cvs` row for it. Reuse the row if that exact CV is already there.
3. Insert the `applications` row. When they report a reply, update `status`, `notes` and
   `updated_at = now()`.

When the user replaces their base CV, keep the old file and rename its row to
`Base CV (until <date>)`, then insert the new file as a fresh `Base CV` row. Also update
`cvs/base-cv.html` (the editable source that tailoring starts from) to match the new CV, and
check it renders to the same content. That way old
applications still point at the CV they were sent with. Answer
questions like "what did I apply to this week" or "which CV did I send to X" from the
database.
