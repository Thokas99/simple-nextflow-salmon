#!/usr/bin/env python3

import argparse
import csv
import json
import sys
from pathlib import Path


FIELDS = [
    "sample",
    "num_processed",
    "num_mapped",
    "mapping_rate",
    "library_type",
    "frag_length_mean",
    "frag_length_sd",
    "salmon_version",
    "fastq_pairs",
    "quantification_directory",
]


def value(meta, key):
    result = meta.get(key)
    return "" if result is None else result


def read_samples(samplesheet):
    counts = {}
    with samplesheet.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = {"sample", "fastq_1", "fastq_2"} - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"samplesheet missing column(s): {', '.join(sorted(missing))}")
        for row in reader:
            sample = row["sample"].strip()
            if sample:
                counts[sample] = counts.get(sample, 0) + 1
    if not counts:
        raise ValueError("samplesheet has no biological samples")
    return counts


def read_meta(sample, quant_dir):
    path = quant_dir / "aux_info" / "meta_info.json"
    if not path.is_file():
        raise FileNotFoundError(f"missing Salmon meta_info.json for sample '{sample}': {path}")
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise ValueError(f"malformed Salmon meta_info.json for sample '{sample}': {path}: {exc}") from exc


def make_row(sample, lane_count, quant_dir, quant_output_dir):
    meta = read_meta(sample, quant_dir)
    processed = meta.get("num_processed")
    mapped = meta.get("num_mapped")
    mapping_rate = meta.get("percent_mapped")
    if mapping_rate is None and processed not in (None, 0) and mapped is not None:
        mapping_rate = 100 * mapped / processed
    library_type = meta.get("detected_library_type")
    if library_type is None:
        library_types = meta.get("library_types") or []
        library_type = ",".join(map(str, library_types))
    if processed == 0:
        print(f"WARNING: sample '{sample}' has zero processed fragments", file=sys.stderr)
    return {
        "sample": sample,
        "num_processed": "" if processed is None else processed,
        "num_mapped": "" if mapped is None else mapped,
        "mapping_rate": "" if mapping_rate is None else mapping_rate,
        "library_type": library_type or "",
        "frag_length_mean": value(meta, "frag_length_mean"),
        "frag_length_sd": value(meta, "frag_length_sd"),
        "salmon_version": value(meta, "salmon_version"),
        "fastq_pairs": lane_count,
        "quantification_directory": str(quant_output_dir / sample),
    }


def main():
    parser = argparse.ArgumentParser(description="Combine per-sample Salmon meta_info.json metrics.")
    parser.add_argument("--samplesheet", type=Path, required=True)
    parser.add_argument("--quant-dirs", type=Path, nargs="+", required=True)
    parser.add_argument("--quant-output-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        samples = read_samples(args.samplesheet)
        quant_dirs = {path.name: path for path in args.quant_dirs}
        missing = [sample for sample in samples if sample not in quant_dirs]
        extra = [sample for sample in quant_dirs if sample not in samples]
        if missing or extra:
            details = []
            if missing:
                details.append(f"missing quantification directory for: {', '.join(missing)}")
            if extra:
                details.append(f"unexpected quantification directory for: {', '.join(extra)}")
            raise ValueError("; ".join(details))
        rows = [
            make_row(sample, lane_count, quant_dirs[sample], args.quant_output_dir)
            for sample, lane_count in samples.items()
        ]
        library_types = {row["library_type"] for row in rows if row["library_type"]}
        if len(library_types) > 1:
            print(f"WARNING: inconsistent inferred library types: {', '.join(sorted(library_types))}", file=sys.stderr)
        with args.output.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()
