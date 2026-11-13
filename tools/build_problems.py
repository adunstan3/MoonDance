#!/usr/bin/env python3
"""Builds Problems.json, the problem snapshot bundled in the watch app.

Source: the community MoonBoard catalog in github.com/boardhang/boardhang-app
(catalog-data/, MIT licence), fetched from the public boardsesh API and curated
there as "benchmark OR at least 10 repeats". This script pins one commit of it.

Filter (SPEC.md, Problem data), per hold set (2016 and 2024, both 40°):
  - every benchmark, every grade
  - the 300 most-repeated non-benchmark V4 problems (6B, 6B+)
  - the 300 most-repeated non-benchmark V5 problems (6C, 6C+)

Usage (from the repo root):
  python3 tools/build_problems.py                # download the pinned snapshot
  python3 tools/build_problems.py --source DIR   # use local copies of the two catalog files

Never edit Problems.json by hand; rerun this script and rebuild the app.
"""

import argparse
import collections
import json
import os
import sys
import urllib.request

DATASET_REPO = "boardhang/boardhang-app"
DATASET_COMMIT = "0ad4fbec3dc204f1a77973e3be197f6d42046597"  # 2026-10-08, refreshed 2024 benchmarks
DATASET_FILES = {
    "2016": "catalog-data/moonboard2016_40.json",
    "2024": "catalog-data/moonboard2024_40.json",
}
EXTRAS_PER_GRADE = 300
EXTRA_V_GRADES = (4, 5)

OUTPUT = os.path.join(os.path.dirname(__file__), "..", "Moon Dance Watch App", "Resources", "Problems.json")

# Font → V, the usual MoonBoard conversion. Must match Grades.swift.
FONT_TO_V = {
    "4": 0, "4+": 0,
    "5": 1, "5+": 2,
    "6A": 3, "6A+": 3,
    "6B": 4, "6B+": 4,
    "6C": 5, "6C+": 5,
    "7A": 6, "7A+": 7,
    "7B": 8, "7B+": 8,
    "7C": 9, "7C+": 10,
    "8A": 11, "8A+": 12,
    "8B": 13, "8B+": 14,
}

ROLE = {"start": "start", "end": "finish"}  # everything else ("right", "left", "middle") is a hand hold
ROLE_ORDER = {"start": 0, "hand": 1, "finish": 2}
COLUMNS = "ABCDEFGHIJK"


def load_catalog(hold_set, source_dir):
    path = DATASET_FILES[hold_set]
    if source_dir:
        with open(os.path.join(source_dir, os.path.basename(path)), encoding="utf-8") as f:
            return json.load(f)
    url = f"https://raw.githubusercontent.com/{DATASET_REPO}/{DATASET_COMMIT}/{path}"
    print(f"Downloading {url}", file=sys.stderr)
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def convert(problem, hold_set):
    grade = problem["grade"]
    if grade not in FONT_TO_V:
        return None
    holds = []
    for hold in problem["holds"]:
        column, row = hold["c"], hold["r"]
        if not (0 <= column < 11 and 1 <= row <= 18):
            return None
        holds.append({"position": f"{COLUMNS[column]}{row}", "role": ROLE.get(hold["t"], "hand")})
    holds.sort(key=lambda h: (ROLE_ORDER[h["role"]], int(h["position"][1:]), h["position"][0]))
    return {
        "id": problem["id"],
        "holdSet": hold_set,
        "name": problem["name"].strip() or "Untitled",
        "setter": (problem.get("setter") or "").strip(),
        "fontGrade": grade,
        "vGrade": FONT_TO_V[grade],
        "isBenchmark": bool(problem["isBenchmark"]),
        "repeats": int(problem.get("repeats") or 0),
        "holds": holds,
    }


def select(problems):
    chosen = [p for p in problems if p["isBenchmark"]]
    for v_grade in EXTRA_V_GRADES:
        extras = [p for p in problems if not p["isBenchmark"] and p["vGrade"] == v_grade]
        extras.sort(key=lambda p: (-p["repeats"], p["name"]))
        chosen += extras[:EXTRAS_PER_GRADE]
    chosen.sort(key=lambda p: (p["vGrade"], -p["repeats"], p["name"]))
    return chosen


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", help="directory holding moonboard2016_40.json and moonboard2024_40.json")
    parser.add_argument("--output", default=OUTPUT)
    args = parser.parse_args()

    everything = []
    for hold_set in ("2016", "2024"):
        catalog = load_catalog(hold_set, args.source)
        converted = [p for p in (convert(raw, hold_set) for raw in catalog["problems"]) if p]
        skipped = len(catalog["problems"]) - len(converted)
        chosen = select(converted)
        everything += chosen

        counts = collections.Counter((p["vGrade"], p["isBenchmark"]) for p in chosen)
        print(f"\n{catalog.get('setup', hold_set)} 40°: {len(chosen)} problems "
              f"(from {len(catalog['problems'])}; {skipped} skipped as unreadable)")
        print("  grade   benchmarks  extras  total")
        for v_grade in sorted({v for v, _ in counts}):
            bench, extra = counts[(v_grade, True)], counts[(v_grade, False)]
            print(f"  V{v_grade:<6} {bench:>10} {extra:>7} {bench + extra:>6}")

    ids = [p["id"] for p in everything]
    if len(ids) != len(set(ids)):
        sys.exit("error: duplicate problem ids")

    # "version" must stay the first key: the app reads it from the file's first
    # bytes on every launch (SnapshotLoader.peekVersion) instead of parsing it all.
    snapshot = {
        "version": f"{DATASET_COMMIT[:7]}-{len(everything)}",
        "source": f"github.com/{DATASET_REPO}@{DATASET_COMMIT[:7]} (boardsesh)",
        "problems": everything,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(snapshot, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    print(f"\nWrote {len(everything)} problems to {os.path.normpath(args.output)}")


if __name__ == "__main__":
    main()
