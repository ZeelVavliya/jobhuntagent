#!/usr/bin/env python3
"""Forward new ai-job-search finds into the career-ops inbox (data/pipeline.md).

ai-job-search's /scrape stores every posting it finds in job_scraper/seen_jobs.json.
This script picks the ones not yet forwarded, drops anything career-ops already
knows (pipeline, tracker, scan history), and appends the rest through
career-ops' own appendToPipeline() (bridge/append_pipeline.mjs).

It never edits seen_jobs.json: the forwarded keys are kept in
bridge/forwarded.json, so ai-job-search's own state rules stay untouched.

Usage (from the job-hunt root):
  python bridge/scrape_to_pipeline.py [--limit 15] [--min-fit medium] [--dry-run]
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AJS = ROOT / "ai-job-search"
CO = ROOT / "career-ops"
LEDGER = Path(__file__).resolve().parent / "forwarded.json"
FIT_RANK = {"low": 0, "medium": 1, "high": 2}
FORWARD_STATUSES = {"new", "ranked", "unreachable"}


def load_seen(path: Path) -> dict:
    if not path.is_file():
        return {}
    doc = json.loads(path.read_text(encoding="utf-8"))
    seen = doc.get("seen") if isinstance(doc, dict) and "seen" in doc else doc
    return seen if isinstance(seen, dict) else {}


def norm_url(url: str) -> str:
    return url.strip().rstrip("/").lower()


def known_urls(co: Path) -> set:
    """Every URL career-ops already has, in its inbox, tracker, reports or scan history."""
    text = ""
    for rel in ("data/pipeline.md", "data/applications.md", "data/scan-history.tsv"):
        p = co / rel
        if p.is_file():
            text += p.read_text(encoding="utf-8", errors="replace").lower() + "\n"
    urls = set()
    for token in text.replace("|", " ").replace("\t", " ").split():
        if token.startswith("http"):
            urls.add(token.strip("()<>[],").rstrip("/"))
    return urls


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--limit", type=int, default=15, help="max postings to forward per run")
    ap.add_argument("--min-fit", choices=FIT_RANK, default="medium",
                    help="skip ai-job-search fit labels below this")
    ap.add_argument("--seen", type=Path, default=AJS / "job_scraper" / "seen_jobs.json")
    ap.add_argument("--career-ops", type=Path, default=CO)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    seen = load_seen(args.seen)
    ledger = json.loads(LEDGER.read_text(encoding="utf-8")) if LEDGER.is_file() else {}
    already = known_urls(args.career_ops)

    offers, keys, skipped = [], [], {"forwarded_before": 0, "known_to_career_ops": 0,
                                     "low_fit": 0, "status": 0, "no_url": 0}
    for key, job in seen.items():
        if not isinstance(job, dict):
            continue
        if key in ledger:
            skipped["forwarded_before"] += 1
            continue
        if job.get("status") not in FORWARD_STATUSES:
            skipped["status"] += 1
            continue
        if FIT_RANK.get(job.get("fit", "medium"), 1) < FIT_RANK[args.min_fit]:
            skipped["low_fit"] += 1
            continue
        url = job.get("url")
        if not isinstance(url, str) or not url.startswith("http"):
            skipped["no_url"] += 1
            continue
        if norm_url(url) in already:
            skipped["known_to_career_ops"] += 1
            ledger[key] = {"at": now(), "url": url, "note": "already in career-ops"}
            continue
        offer = {"url": url.strip(), "company": str(job.get("company", "")).strip(),
                 "title": str(job.get("title", "")).strip()}
        if isinstance(job.get("location"), str):
            offer["location"] = job["location"]
        offers.append(offer)
        keys.append(key)
        if len(offers) >= args.limit:
            break

    if offers and not args.dry_run:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as fh:
            json.dump(offers, fh)
            tmp = fh.name
        try:
            res = subprocess.run(
                ["node", str(Path(__file__).with_name("append_pipeline.mjs")), str(args.career_ops), tmp],
                capture_output=True, text=True)
        finally:
            os.unlink(tmp)
        if res.returncode != 0:
            print(json.dumps({"error": "append failed", "stderr": res.stderr[-2000:]}))
            return 1
        for key, offer in zip(keys, offers):
            ledger[key] = {"at": now(), "url": offer["url"]}
    if not args.dry_run:
        LEDGER.write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps({"forwarded": len(offers) if not args.dry_run else 0,
                      "would_forward": len(offers) if args.dry_run else None,
                      "offers": offers, "skipped": skipped}, ensure_ascii=False))
    return 0


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


if __name__ == "__main__":
    sys.exit(main())
