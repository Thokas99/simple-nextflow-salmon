#!/usr/bin/env python3
"""Validate an SnS CSV and emit normalized JSON for Nextflow."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
from collections import OrderedDict
from pathlib import Path


REQUIRED = ["sample", "fastq_1", "fastq_2"]
SAFE_SAMPLE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")
FASTQ_EXT = re.compile(r"\.f(?:ast)?q(?:\.gz)?$", re.IGNORECASE)


def validate(path: Path, launch_dir: Path) -> dict:
    errors: list[str] = []
    rows: list[dict] = []
    owners: dict[Path, tuple[str, int]] = {}
    basenames: dict[str, tuple[Path, int]] = {}
    row_keys: set[tuple[str, Path, Path]] = set()
    try:
        handle = path.open(newline="", encoding="utf-8-sig")
    except OSError as exc:
        raise ValueError(f"cannot read samplesheet '{path}': {exc}") from exc
    with handle:
        try:
            reader = csv.DictReader(handle, strict=True)
            header = reader.fieldnames or []
            if header != REQUIRED:
                errors.append(f"header: expected exactly {','.join(REQUIRED)}; found {','.join(header) or '<empty>'}")
            for line, raw in enumerate(reader, 2):
                if None in raw:
                    errors.append(f"row {line}: too many fields")
                    continue
                values = {key: (raw.get(key) or "").strip() for key in REQUIRED}
                for key, value in values.items():
                    if not value:
                        errors.append(f"row {line}, {key}: value is empty")
                sample = values["sample"]
                if sample and not SAFE_SAMPLE.fullmatch(sample):
                    errors.append(f"row {line}, sample: unsafe identifier '{sample}'")
                if not all(values.values()):
                    continue
                pair = []
                for field in ("fastq_1", "fastq_2"):
                    supplied = Path(values[field]).expanduser()
                    resolved = (supplied if supplied.is_absolute() else launch_dir / supplied).resolve()
                    pair.append(resolved)
                    if not FASTQ_EXT.search(resolved.name):
                        errors.append(f"row {line}, {field}: unsupported FASTQ extension '{resolved.name}'")
                    if not resolved.is_file():
                        errors.append(f"row {line}, {field}: file not found '{resolved}'")
                    elif not os.access(resolved, os.R_OK):
                        errors.append(f"row {line}, {field}: file is not readable '{resolved}'")
                    previous = owners.get(resolved)
                    if previous:
                        relation = "within sample" if previous[0] == sample else f"across samples '{previous[0]}' and '{sample}'"
                        errors.append(f"row {line}, {field}: FASTQ repeated {relation}; first assigned at row {previous[1]}")
                    else:
                        owners[resolved] = (sample, line)
                    named = basenames.get(resolved.name)
                    if named and named[0] != resolved:
                        errors.append(f"row {line}, {field}: basename collision '{resolved.name}' with row {named[1]}")
                    else:
                        basenames[resolved.name] = (resolved, line)
                r1, r2 = pair
                if r1 == r2:
                    errors.append(f"row {line}: fastq_1 and fastq_2 resolve to the same file")
                key = (sample, r1, r2)
                if key in row_keys:
                    errors.append(f"row {line}: duplicate samplesheet row")
                row_keys.add(key)
                rows.append({"sample": sample, "fastq_1": str(r1), "fastq_2": str(r2), "row": line})
        except csv.Error as exc:
            errors.append(f"CSV parse error near row {reader.line_num}: {exc}")
    if not rows:
        errors.append("samplesheet has no data rows")
    if errors:
        raise ValueError("Samplesheet validation failed:\n- " + "\n- ".join(dict.fromkeys(errors)))

    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    for row in rows:
        grouped.setdefault(row["sample"], []).append(row)
    samples = [
        {"sample": sample, "fastq_1": [row["fastq_1"] for row in lanes],
         "fastq_2": [row["fastq_2"] for row in lanes], "fastq_pairs": len(lanes)}
        for sample, lanes in grouped.items()
    ]
    return {"rows": rows, "samples": samples, "biological_samples": len(samples),
            "fastq_pairs": len(rows), "technical_replicate_samples": sum(s["fastq_pairs"] > 1 for s in samples)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("samplesheet", type=Path)
    parser.add_argument("--launch-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(validate(args.samplesheet.resolve(), args.launch_dir.resolve()), separators=(",", ":")))
        return 0
    except ValueError as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
