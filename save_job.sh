#!/bin/sh
# Saves one job from freehire into the jobs table, with its JobStreet ad link.
# Run it when an application is logged; search results are no longer saved. Usage: ./save_job.sh <slug>...
for slug; do
  json=$(curl -sf "https://freehire.me/api/v1/jobs/$slug" | python3 -c '
import sys, json
j = json.load(sys.stdin)["data"]
j["slug"] = j.pop("public_slug")
j["official_job_url"] = j.pop("url").split("?utm_")[0]
print(json.dumps(j))') || { echo "$slug: not found on freehire" >&2; exit 1; }
  echo "select save_jobs(:'json'::jsonb)" |
    docker exec -i job-hunt-db psql -U jobs -d jobs -qAt -v ON_ERROR_STOP=1 -v json="$json" >/dev/null
  echo "$slug saved"
done
