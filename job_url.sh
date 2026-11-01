#!/bin/sh
# Looks up each job's original ad URL (freehire's MCP tools leave it out for JobStreet),
# saves it to jobs.official_job_url and prints "slug url". Usage: ./job_url.sh <slug>...
for slug; do
  url=$(curl -sf "https://freehire.me/api/v1/jobs/$slug" |
    python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["url"].split("?utm_")[0])' 2>/dev/null) || continue
  case $url in https://*) ;; *) continue ;; esac
  echo "update jobs set official_job_url = :'url' where slug = :'slug'" |
    docker exec -i job-hunt-db psql -U jobs -d jobs -q -v slug="$slug" -v url="$url"
  echo "$slug $url"
done
