#!/usr/bin/env python3
"""Search LinkedIn (public guest pages) and freehire.me, filter titles with
career-ops' own portals.yml title_filter, and append new postings to the
career-ops inbox through career-ops' appendToPipeline() (append_pipeline.mjs).

Replaces ai-job-search's LLM-driven /scrape, so ai-job-search needs no profile
setup: only its two zero-dependency portal CLIs are used.
Seek and Atlassian are scanned by career-ops itself (`node scan.mjs`, portals.yml).

LinkedIn stays at 2 queries per run, posted in the last 24h (its Terms of
Service forbid heavy automation). Queries rotate across runs.

Usage (from the job-hunt root):
  python3 bridge/search_boards.py [--limit 15] [--dry-run]
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AJS = ROOT / "ai-job-search"
CO = ROOT / "career-ops"
LEDGER = Path(__file__).resolve().parent / "forwarded.json"

LINKEDIN_PERTH = ["graduate software engineer", "software engineer intern", "junior data analyst",
                  "graduate data scientist", "machine learning graduate", "junior software developer"]
LINKEDIN_REMOTE_AU = ["graduate software engineer", "data science graduate", "machine learning engineer junior",
                      "data analyst graduate", "software engineering internship", "AI engineer graduate"]
FREEHIRE_QUERIES = ["software engineer OR software developer", "data scientist OR data analyst OR machine learning"]


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_cli(skill: str, args: list) -> list:
    cli = AJS / ".agents" / "skills" / skill / "cli" / "src" / "cli.ts"
    res = subprocess.run(["bun", "run", str(cli), *args], capture_output=True, text=True,
                         cwd=str(AJS), timeout=120)
    if res.returncode != 0:
        raise RuntimeError(f"{skill}: {res.stderr.strip()[-300:]}")
    doc = json.loads(res.stdout or "{}")
    return doc.get("results", []) if isinstance(doc, dict) else []


def load_title_filter() -> tuple:
    import yaml  # python3-yaml, installed in the container
    doc = yaml.safe_load((CO / "portals.yml").read_text(encoding="utf-8")) or {}
    tf = doc.get("title_filter") or {}
    return [str(x) for x in tf.get("positive") or []], [str(x) for x in tf.get("negative") or []]


def _matcher(entry: str):
    """Mirror career-ops' title_filter rules: plain = substring (2-3 letter = whole word),
    word: = whole word, stem: = must start a word."""
    if entry.startswith("word:"):
        return re.compile(r"(?<![A-Za-z0-9])" + re.escape(entry[5:]) + r"(?![A-Za-z0-9])", re.I)
    if entry.startswith("stem:"):
        return re.compile(r"(?<![A-Za-z0-9])" + re.escape(entry[5:]), re.I)
    if 2 <= len(entry) <= 3 and entry.isalpha():
        return re.compile(r"(?<![A-Za-z0-9])" + re.escape(entry) + r"(?![A-Za-z0-9])", re.I)
    return re.compile(re.escape(entry), re.I)


def title_ok(title: str, pos: list, neg: list) -> bool:
    if pos and not any(m.search(title) for m in pos):
        return False
    return not any(m.search(title) for m in neg)


def known_urls() -> set:
    text = ""
    for rel in ("data/pipeline.md", "data/applications.md", "data/scan-history.tsv"):
        p = CO / rel
        if p.is_file():
            text += p.read_text(encoding="utf-8", errors="replace").lower() + "\n"
    out = set()
    for tok in text.replace("|", " ").replace("\t", " ").split():
        if tok.startswith("http"):
            out.add(tok.strip("()<>[],").rstrip("/"))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=15)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    slot = int(datetime.now().strftime("%j")) * 3 + datetime.now().hour // 8
    li_queries = [
        ("linkedin-search", ["search", "-q", LINKEDIN_PERTH[slot % len(LINKEDIN_PERTH)],
                             "-l", "Perth, Western Australia, Australia", "--jobage", "1", "--format", "json"]),
        ("linkedin-search", ["search", "-q", LINKEDIN_REMOTE_AU[slot % len(LINKEDIN_REMOTE_AU)],
                             "-l", "Australia", "--remote", "remote", "--jobage", "1", "--format", "json"]),
    ]
    fh_queries = [("freehire-search", ["search", "-q", q, "--country", "AU", "--jobage", "3",
                                       "--limit", "25", "--format", "json"]) for q in FREEHIRE_QUERIES]

    pos_raw, neg_raw = load_title_filter()
    pos, neg = [_matcher(x) for x in pos_raw], [_matcher(x) for x in neg_raw]
    ledger = json.loads(LEDGER.read_text(encoding="utf-8")) if LEDGER.is_file() else {}
    already = known_urls()

    found, errors, offers = 0, [], []
    stats = {"title_filtered": 0, "known": 0, "forwarded_before": 0}
    seen_now = set()
    for skill, cli_args in li_queries + fh_queries:
        try:
            rows = run_cli(skill, cli_args)
        except Exception as e:  # one source failing must not stop the others
            errors.append(str(e)[:200])
            continue
        for r in rows:
            found += 1
            url = str(r.get("url") or "").strip()
            title = str(r.get("title") or "").strip()
            if not url.startswith("http") or not title:
                continue
            key = url.rstrip("/").lower()
            if key in seen_now:
                continue
            seen_now.add(key)
            if key in ledger:
                stats["forwarded_before"] += 1
                continue
            if key in already:
                stats["known"] += 1
                ledger[key] = {"at": now(), "note": "already in career-ops"}
                continue
            if not title_ok(title, pos, neg):
                stats["title_filtered"] += 1
                continue
            offer = {"url": url, "company": str(r.get("company") or "").strip(), "title": title}
            if r.get("location"):
                offer["location"] = str(r["location"])
            offers.append(offer)
            if len(offers) >= args.limit:
                break
        if len(offers) >= args.limit:
            break

    if offers and not args.dry_run:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as fh:
            json.dump(offers, fh)
            tmp = fh.name
        try:
            res = subprocess.run(["node", str(Path(__file__).with_name("append_pipeline.mjs")), str(CO), tmp],
                                 capture_output=True, text=True)
        finally:
            os.unlink(tmp)
        if res.returncode != 0:
            print(json.dumps({"found": found, "forwarded": 0, "errors": errors + ["append failed: " + res.stderr[-300:]]}))
            return 1
        for o in offers:
            ledger[o["url"].rstrip("/").lower()] = {"at": now()}
    if not args.dry_run:
        LEDGER.write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps({"found": found, "forwarded": 0 if args.dry_run else len(offers),
                      "would_forward": len(offers) if args.dry_run else None,
                      "skipped": stats, "errors": errors, "offers": offers}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
