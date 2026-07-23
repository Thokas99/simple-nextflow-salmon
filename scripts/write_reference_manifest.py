#!/usr/bin/env python3
"""Write the deterministic derived-reference compatibility manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_checksums(path: Path) -> dict[str, dict[str, str]]:
    records: dict[str, dict[str, str]] = {}
    for line in path.read_text().splitlines():
        sha, name = line.split(maxsplit=1)
        filename = Path(name).name
        records[filename] = {"filename": filename, "sha256": sha}
    return records


def pick(records: dict[str, dict[str, str]], contains: str) -> dict[str, str]:
    matches = [v for k, v in records.items() if contains in k]
    if len(matches) != 1:
        raise SystemExit(f"Expected one checksum record containing {contains}, found {len(matches)}")
    return matches[0]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checksums", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--pipeline_version", required=True)
    parser.add_argument("--gencode_release", required=True)
    parser.add_argument("--genome_patch", required=True)
    parser.add_argument("--salmon_version", required=True)
    parser.add_argument("--salmon_k", required=True)
    parser.add_argument("--salmon_index_options", required=True)
    parser.add_argument("--decoy_generation_method", required=True)
    args = parser.parse_args()

    records = read_checksums(args.checksums)
    tx = pick(records, ".transcripts.fa.gz")
    genome = pick(records, ".genome.fa.gz")
    gtf = pick(records, ".gtf.gz")

    manifest = {
        "manifest_format_version": 1,
        "pipeline_version": args.pipeline_version,
        "gencode_release": str(args.gencode_release),
        "grch38_patch": str(args.genome_patch),
        "transcript_fasta_filename": tx["filename"],
        "transcript_fasta_sha256": tx["sha256"],
        "genome_fasta_filename": genome["filename"],
        "genome_fasta_sha256": genome["sha256"],
        "gtf_filename": gtf["filename"],
        "gtf_sha256": gtf["sha256"],
        "salmon_version": str(args.salmon_version),
        "salmon_index_k": str(args.salmon_k),
        "salmon_index_options": args.salmon_index_options,
        "decoy_generation_method": args.decoy_generation_method,
    }
    args.out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
