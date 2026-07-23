#!/usr/bin/env python3
"""Validate and normalize the simple-nextflow-salmon samplesheet."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path


REQUIRED = ["sample", "fastq_1", "fastq_2"]
SAFE_SAMPLE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")


def sniff(path: Path) -> str:
    first = path.read_text(newline="").splitlines()[0]
    if "\t" in first and "," not in first:
        return "\t"
    return ","


def validate(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise SystemExit(f"Samplesheet does not exist: {path}")

    dialect = csv.excel_tab if sniff(path) == "\t" else csv.excel
    rows: list[dict[str, str]] = []
    seen_samples: set[str] = set()
    seen_fastqs: set[Path] = set()

    with path.open(newline="") as handle:
        reader = csv.reader(handle, dialect=dialect)
        try:
            header = [h.strip() for h in next(reader)]
        except StopIteration:
            raise SystemExit(f"Samplesheet is empty: {path}") from None

        duplicates = sorted({h for h in header if header.count(h) > 1})
        if duplicates:
            raise SystemExit("Duplicate samplesheet header(s): " + ", ".join(duplicates))

        missing = [col for col in REQUIRED if col not in header]
        if missing:
            raise SystemExit("Missing samplesheet column(s): " + ", ".join(missing))

        extra = [col for col in header if col not in REQUIRED]
        if extra:
            raise SystemExit("Unexpected samplesheet column(s): " + ", ".join(extra))

        index = {name: header.index(name) for name in REQUIRED}
        for line_no, fields in enumerate(reader, start=2):
            if not fields or all(not f.strip() for f in fields):
                continue
            if len(fields) != len(header):
                raise SystemExit(f"Malformed samplesheet row {line_no}: expected {len(header)} fields, got {len(fields)}")

            sample = fields[index["sample"]].strip()
            r1 = fields[index["fastq_1"]].strip()
            r2 = fields[index["fastq_2"]].strip()

            if not sample:
                raise SystemExit(f"Empty sample ID on row {line_no}")
            if not SAFE_SAMPLE.match(sample):
                raise SystemExit(f"Unsafe sample ID on row {line_no}: {sample}")
            if sample in seen_samples:
                raise SystemExit(f"Duplicate sample ID: {sample}")
            if not r1 or not r2:
                raise SystemExit(f"Sample '{sample}' must have both fastq_1 and fastq_2")

            p1 = Path(r1).expanduser().resolve()
            p2 = Path(r2).expanduser().resolve()
            if p1 == p2:
                raise SystemExit(f"Sample '{sample}' has identical fastq_1 and fastq_2")
            for fastq in (p1, p2):
                if fastq in seen_fastqs:
                    raise SystemExit(f"FASTQ assigned more than once: {fastq}")
                if not fastq.is_file():
                    raise SystemExit(f"FASTQ does not exist: {fastq}")
                seen_fastqs.add(fastq)

            seen_samples.add(sample)
            rows.append({"sample": sample, "fastq_1": str(p1), "fastq_2": str(p2)})

    if not rows:
        raise SystemExit(f"Samplesheet has no sample rows: {path}")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate sample,fastq_1,fastq_2 CSV/TSV")
    parser.add_argument("samplesheet", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    rows = validate(args.samplesheet)
    if args.json:
        print(json.dumps({"rows": rows}))
    else:
        print(f"Validated {len(rows)} sample(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
