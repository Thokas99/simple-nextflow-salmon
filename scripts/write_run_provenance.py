#!/usr/bin/env python3
"""Combine run-level provenance into a small JSON file."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--pipeline_version", required=True)
    parser.add_argument("--samplesheet", type=Path, required=True)
    parser.add_argument("--reference_manifest", type=Path, required=True)
    parser.add_argument("--software_versions", type=Path, required=True)
    args = parser.parse_args()

    data = {
        "pipeline": "simple-nextflow-salmon",
        "pipeline_version": args.pipeline_version,
        "samplesheet": str(args.samplesheet),
        "reference_manifest": json.loads(args.reference_manifest.read_text()),
        "software_versions_file": str(args.software_versions),
    }
    args.out.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
