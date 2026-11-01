# job-hunt-db

Use Claude Code to search JobStreet for jobs that match your CV, tailor your CV to each job,
and fill in the application form, stopping before Submit. Jobs come from
[freehire](https://freehire.me) and include visa-sponsorship screening. Your applications
are tracked in a small Postgres database.

## What you need

- [Claude Code](https://claude.com/claude-code)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Google Chrome with the **Claude in Chrome** extension, to fill in application forms
- A JobStreet account, signed in in that Chrome

## Setup

```bash
git clone <this repo> job-hunt-db
cd job-hunt-db
docker compose up -d            # starts Postgres and creates the tables
cp applicant.example.md applicant.md
```

1. Fill in `applicant.md`: search country, contact details, notice period, salary, and
   whether you need visa sponsorship.
2. Put your CV (PDF or Word) in `cvs/`.
3. Open Claude Code **in this folder** and type `/job-hunt`. The first time, Claude turns
   your CV into `cvs/base-cv.html`, the editable copy it tailors from. Check the PDF it
   makes against your original.

Claude Code will ask you to approve the freehire connection (`.mcp.json`) the first time.

## Using it

- `/job-hunt backend developer jobs` searches JobStreet, screens the jobs against your CV
  (experience, education, skills, work rights) and lists the ones that fit, with reasons and gaps.
- `apply to number 2` tailors a copy of your CV to that job, opens the form in Chrome, fills it
  in, and **stops before Submit** so you can review and submit it yourself.
- `what have I applied to this week?`, `which CV did I send to <company>?`, or
  `mark <company> as interviewing` all answer from the database.

Tailored CVs only reorder and reword what's in your base CV. Claude is told never to add
skills, experience or claims your CV doesn't have.

## What's in here

| File | What it does |
|---|---|
| `.claude/skills/job-hunt/SKILL.md` | The instructions Claude follows for searching, tailoring and applying |
| `.mcp.json` | Connects Claude Code to freehire's job search (read-only, no key) |
| `docker-compose.yml`, `schema.sql` | Postgres 17 with the `jobs`, `cvs` and `applications` tables and the `jobs_by_location` view |
| `render_cv.sh` | Turns a CV's HTML into a PDF using headless Chrome |
| `job_url.sh` | Looks up a job's JobStreet link (freehire's search tools leave it out) |
| `save_job.sh` | Saves a job to the database when you log an application |
| `check.sh` | Self-test: `./check.sh` should print `ok` |
| `applicant.example.md`, `cvs/base-cv.example.html` | Templates for your own details and CV |

Your personal files (`applicant.md`, everything in `cvs/` except the template, and CSV
exports) are in `.gitignore`, so they're never committed.

## Notes

- The database listens only on `127.0.0.1:5432` with the login `jobs` / `jobs`. If port 5432
  is already in use, change the left-hand port in `docker-compose.yml`.
- `render_cv.sh` expects Chrome at `/Applications/Google Chrome.app` (macOS). On Linux or
  Windows, change the path in the script.
- freehire doesn't cover LinkedIn, and Claude never scrapes it.
