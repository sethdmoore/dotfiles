#!/usr/bin/env python3
"""Append a note (optionally with child bullets) to a Logseq page via the local HTTP gateway.

Defaults to today's journal. Resolves the journal page name from the user's
`preferredDateFormat` so it works regardless of how the graph is configured, and
verifies the write by reading the block back.

Usage:
  append_note.py "PARENT CONTENT" [--child "line"]... [options]

Options:
  --child TEXT     A child bullet under the parent. Repeatable.
  --page NAME      Append to this page instead of a journal (e.g. "Project X").
  --date YYYY-MM-DD  Target this journal day instead of today.
  --tz ZONE        Timezone for "today" (default America/New_York — user is US Eastern).
  --dry-run        Print the resolved page + payload without writing.

Env: LOGSEQ_API_URL, LOGSEQ_API_TOKEN (token is never printed).
"""
import argparse, json, os, re, sys, urllib.request
from datetime import datetime, date

try:
    from zoneinfo import ZoneInfo
except ImportError:
    ZoneInfo = None


def api(method, args):
    base = os.environ["LOGSEQ_API_URL"].rstrip("/") + "/api"
    token = os.environ["LOGSEQ_API_TOKEN"]
    body = json.dumps({"method": method, "args": args}).encode()
    req = urllib.request.Request(
        base, data=body,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read().decode()
        return json.loads(raw) if raw.strip() else None


_MONTHS = ["January", "February", "March", "April", "May", "June", "July",
           "August", "September", "October", "November", "December"]


def _ordinal(n):
    if 10 <= n % 100 <= 20:
        suf = "th"
    else:
        suf = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    return f"{n}{suf}"


def format_journal_title(d: date, fmt: str) -> str:
    """Render a date using Logseq/moment-style tokens (covers the common formats)."""
    tok = {
        "yyyy": lambda: f"{d.year:04d}",
        "yy": lambda: f"{d.year % 100:02d}",
        "MMMM": lambda: _MONTHS[d.month - 1],
        "MMM": lambda: _MONTHS[d.month - 1][:3],
        "MM": lambda: f"{d.month:02d}",
        "M": lambda: str(d.month),
        "dddd": lambda: d.strftime("%A"),
        "ddd": lambda: d.strftime("%a"),
        "do": lambda: _ordinal(d.day),
        "dd": lambda: f"{d.day:02d}",
        "d": lambda: str(d.day),
    }
    pat = re.compile(r"yyyy|yy|MMMM|MMM|MM|M|dddd|ddd|dd|do|d")
    return pat.sub(lambda m: tok[m.group(0)](), fmt)


def resolve_journal_page(d: date) -> str:
    """Prefer the existing journal page's real name (by journal-day); else format it."""
    jd = d.year * 10000 + d.month * 100 + d.day
    try:
        q = f'[:find ?n :where [?p :block/journal-day {jd}] [?p :block/original-name ?n]]'
        res = api("logseq.DB.datascriptQuery", [q])
        if res and res[0] and res[0][0]:
            return res[0][0]
    except Exception:
        pass
    cfg = api("logseq.App.getUserConfigs", []) or {}
    fmt = cfg.get("preferredDateFormat", "MMM do, yyyy")
    return format_journal_title(d, fmt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("parent")
    ap.add_argument("--child", action="append", default=[])
    ap.add_argument("--page")
    ap.add_argument("--date")
    ap.add_argument("--tz", default="America/New_York")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    if a.page:
        page = a.page
    else:
        if a.date:
            d = datetime.strptime(a.date, "%Y-%m-%d").date()
        elif ZoneInfo:
            d = datetime.now(ZoneInfo(a.tz)).date()
        else:
            d = datetime.now().date()
        page = resolve_journal_page(d)

    print(f"target page: {page}")
    print(f"parent: {a.parent}")
    for c in a.child:
        print(f"  - {c}")
    if a.dry_run:
        print("[dry-run] nothing written")
        return

    parent = api("logseq.Editor.appendBlockInPage", [page, a.parent])
    uuid = parent.get("uuid") if isinstance(parent, dict) else None
    if not uuid:
        print("ERROR: no uuid returned; parent may not have been created", file=sys.stderr)
        sys.exit(1)
    if a.child:
        api("logseq.Editor.insertBatchBlock",
            [uuid, [{"content": c} for c in a.child], {"sibling": False}])

    # verify
    block = api("logseq.Editor.getBlock", [uuid, {"includeChildren": True}])
    kids = (block or {}).get("children") or []
    print(f"OK: wrote parent + {len(kids)} child block(s) to '{page}' (uuid {uuid})")


if __name__ == "__main__":
    main()
