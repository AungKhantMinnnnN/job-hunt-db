#!/bin/sh
# Self-check: saves a fake job through save_jobs(), asserts its fields came back, deletes it.
# Needs only the running database (no network). Usage: ./check.sh
set -e
q() { docker exec job-hunt-db psql -U jobs -d jobs -qAt -v ON_ERROR_STOP=1 -c "$1"; }

q "select save_jobs('{\"slug\":\"zz-selftest\",\"title\":\"Test\",\"company\":\"Acme\",\"countries\":[\"sg\"],\"official_job_url\":\"https://example.com/1\",\"description\":\"it''s fine\"}'::jsonb)" >/dev/null
got=$(q "select j.company || '|' || j.official_job_url || '|' || j.description || '|' || l.country
         from jobs j join jobs_by_location l using (slug) where slug = 'zz-selftest'")
q "delete from jobs where slug = 'zz-selftest'"
[ "$got" = "Acme|https://example.com/1|it's fine|Singapore" ] && echo ok || { echo "FAIL: got '$got'"; exit 1; }
