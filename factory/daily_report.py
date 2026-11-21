#!/usr/bin/env python3
"""Posts a daily summary issue: AI pull requests and cycle results from the last 24 hours."""
import json
import subprocess
from datetime import datetime, timedelta, timezone


def gh(*args):
    p = subprocess.run(["gh", *args], capture_output=True, text=True)
    return p.stdout


def main():
    since = datetime.now(timezone.utc) - timedelta(hours=24)
    prs = json.loads(gh("pr", "list", "--label", "ai-factory", "--state", "all", "--limit", "50",
                        "--json", "number,title,state,createdAt,url") or "[]")
    prs = [p for p in prs if datetime.fromisoformat(p["createdAt"].replace("Z", "+00:00")) >= since]
    runs = json.loads(gh("run", "list", "--workflow", "factory.yml", "--limit", "20",
                         "--json", "conclusion,createdAt") or "[]")
    runs = [r for r in runs if datetime.fromisoformat(r["createdAt"].replace("Z", "+00:00")) >= since]
    ok = sum(1 for r in runs if r["conclusion"] == "success")
    lines = ["# GramJeevan daily report %s" % datetime.now(timezone.utc).strftime("%Y-%m-%d"), "",
             "- Cycles run (24h): %d (%d completed, %d errored)" % (len(runs), ok, len(runs) - ok),
             "- AI pull requests created: %d" % len(prs), ""]
    lines += ["- #%d [%s] %s: %s" % (p["number"], p["state"], p["title"], p["url"]) for p in prs]
    if not prs:
        lines.append("No new pull requests today. See the Factory Log issue for the reason.")
    lines += ["", "Review open AI pull requests and merge the ones you like."]
    gh("label", "create", "daily-report", "--force", "--color", "FBCA04")
    gh("issue", "create", "--title", "Daily report " + datetime.now(timezone.utc).strftime("%Y-%m-%d"),
       "--label", "daily-report", "--body", "\n".join(lines))


if __name__ == "__main__":
    main()
