#!/usr/bin/env python3
"""Create a Salmon samplesheet from paired FASTQ filenames.

Lane tokens are kept in the sample name. This workflow intentionally does not
merge lanes; one detected R1/R2 pair becomes one final sample row.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path


FASTQ_RE = re.compile(
    r"^(?P<sample>.+?)(?:[_.-]R(?P<read_a>[12])|[_.-](?P<read_b>[12]))(?:[_.-]001)?(?P<ext>\.f(?:ast)?q(?:\.gz)?)$",
    re.IGNORECASE,
)


def find_fastqs(fastq_dir: Path) -> list[Path]:
    return sorted(p for p in fastq_dir.rglob("*") if p.is_file() and FASTQ_RE.match(p.name))


def build_rows(fastqs: list[Path]) -> list[dict[str, str]]:
    pairs: dict[str, dict[str, Path]] = {}

    for fastq in fastqs:
        match = FASTQ_RE.match(fastq.name)
        if not match:
            continue
        sample = match.group("sample")
        read = match.group("read_a") or match.group("read_b")
        slot = pairs.setdefault(sample, {})
        if read in slot:
            raise SystemExit(f"Duplicate R{read} FASTQ for sample '{sample}': {fastq}")
        slot[read] = fastq.resolve()

    missing = sorted(sample for sample, reads in pairs.items() if "1" not in reads or "2" not in reads)
    if missing:
        raise SystemExit("Missing pair for sample(s): " + ", ".join(missing))

    return [
        {"sample": sample, "fastq_1": str(reads["1"]), "fastq_2": str(reads["2"])}
        for sample, reads in sorted(pairs.items())
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Create sample,fastq_1,fastq_2 CSV from paired FASTQ files.")
    parser.add_argument("fastq_dir", type=Path, help="Directory containing FASTQ files")
    parser.add_argument("-o", "--out", type=Path, default=Path("samplesheet.csv"), help="Output CSV path")
    parser.add_argument("--json", action="store_true", help="Print machine-readable summary")
    args = parser.parse_args()

    if not args.fastq_dir.is_dir():
        raise SystemExit(f"FASTQ directory does not exist: {args.fastq_dir}")

    rows = build_rows(find_fastqs(args.fastq_dir))
    if not rows:
        raise SystemExit(f"No paired FASTQ filenames found in: {args.fastq_dir}")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["sample", "fastq_1", "fastq_2"])
        writer.writeheader()
        writer.writerows(rows)

    if args.json:
        print(json.dumps({"samplesheet": str(args.out.resolve()), "samples": len(rows)}))
    else:
        print(f"Wrote {len(rows)} sample(s) to {args.out}")
        print("Inspect this file before running the full pipeline.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
