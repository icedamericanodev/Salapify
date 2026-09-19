#!/usr/bin/env python3
"""Measures the migration against what a PERSON can see, not what I ported.

WHY THIS EXISTS
---------------
The founder asked, on 2026-09-19, why so much of the prototype was still
missing and why they kept having to point it out. The honest answer is that
every audit so far measured the wrong thing:

  - docs/migration/coverage-audit.md compared RECORD COUNTS. InstallmentPlan
    passed on three-against-three while holding four of its twenty two fields.
  - Before that, the Academy was "ported" because AcademyView.tsx had been
    read. The thirty two real courses were in src/data/academyData.ts, a file
    nobody opened, and six invented ones shipped instead.
  - Screens were checked off by reading the top level component and stopping,
    so BankAmortizationTable.tsx, 691 lines rendered INSIDE the calculators,
    was never counted as missing at all.
  - "Deferred, written down" was treated as a finished state. Individually
    each note was reasonable. Added up, they are the reason the app looks
    half built to the person using it.

All four are the same mistake: auditing MY units of work (files, engines,
records, plans) instead of the user's unit (a thing I can see and tap).

So this counts BUTTONS, TABS AND HEADINGS: the prototype's own visible
surface, extracted from its source rather than from anybody's memory, then
looked for in app/lib. It cannot be satisfied by a plan or a note. A label
that exists in the prototype and nowhere in app/ is a thing the founder can
find and I cannot explain away.

It is a SIGNAL, not a gate. Wording legitimately differs (the prototype says
"Work it out", we might say "Amortization"), so a miss is a question to answer,
not a failure. The number's job is to stop the migration being declared done
by the person doing it.

    python3 tool/surface_audit.py            # summary per prototype screen
    python3 tool/surface_audit.py --missing  # every label with no match
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "src" / "components"
APP = ROOT / "app" / "lib"

# Text sitting directly inside a JSX element, which is what a person reads.
TEXT_IN_TAG = re.compile(r">\s*([A-Z][^<>{}\n]{2,40}?)\s*<")
# label: 'Foo' and name: "Foo", which is how the prototype declares its tabs.
LABELLED = re.compile(r"\b(?:label|name|title|placeholder)\s*:\s*['\"]([^'\"]{3,40})['\"]")

# Words that are code or markup rather than something a person reads.
NOISE = re.compile(
    r"^(?:[A-Z_]+|true|false|null|undefined|div|span|button|React|"
    r"[0-9.,%₱\s]+)$"
)


def visible_labels(text: str) -> set[str]:
    """Every string in this file a person could read on screen."""
    found: set[str] = set()
    for match in list(TEXT_IN_TAG.findall(text)) + list(LABELLED.findall(text)):
        label = " ".join(match.split())
        if not label or NOISE.match(label):
            continue
        # Drop anything that is plainly an expression rather than prose.
        if any(ch in label for ch in "{}()=;$"):
            continue
        found.add(label)
    return found


def normalise(s: str) -> str:
    """Compares on letters alone, so punctuation and case never hide a match."""
    return re.sub(r"[^a-z0-9]", "", s.lower())


def app_corpus() -> str:
    parts: list[str] = []
    for path in APP.rglob("*.dart"):
        parts.append(path.read_text(encoding="utf-8", errors="ignore"))
    return normalise("\n".join(parts))


def main() -> int:
    if not SRC.is_dir():
        print(f"no prototype at {SRC}", file=sys.stderr)
        return 2

    corpus = app_corpus()
    show_missing = "--missing" in sys.argv

    rows: list[tuple[str, int, int]] = []
    all_missing: dict[str, list[str]] = {}

    for path in sorted(SRC.glob("*.tsx")):
        labels = visible_labels(path.read_text(encoding="utf-8", errors="ignore"))
        if not labels:
            continue
        missing = sorted(l for l in labels if normalise(l) not in corpus)
        rows.append((path.name, len(labels) - len(missing), len(labels)))
        if missing:
            all_missing[path.name] = missing

    rows.sort(key=lambda r: (r[1] / r[2] if r[2] else 1))

    total_have = sum(r[1] for r in rows)
    total_all = sum(r[2] for r in rows)

    print(f"{'prototype screen':<42}{'covered':>10}")
    print("-" * 52)
    for name, have, total in rows:
        pct = 100 * have / total if total else 100
        print(f"{name:<42}{have:>4}/{total:<4} {pct:>3.0f}%")
    print("-" * 52)
    print(
        f"{'TOTAL':<42}{total_have:>4}/{total_all:<4} "
        f"{100 * total_have / total_all:>3.0f}%"
    )

    if show_missing:
        print()
        for name, missing in sorted(all_missing.items()):
            print(f"\n## {name}")
            for label in missing:
                print(f"  - {label}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
