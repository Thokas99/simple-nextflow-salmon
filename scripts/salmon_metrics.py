#!/usr/bin/env python3
"""Export native Salmon metadata and pipeline-specific RNA summary metrics."""

import argparse
import csv
import json
from pathlib import Path


FIELDS = [
    "sample", "num_processed", "num_mapped", "percent_mapped", "detected_library_type",
    "frag_length_mean", "frag_length_sd", "salmon_version", "fastq_pairs",
]


def value(meta, key):
    result = meta.get(key)
    return "" if result is None else result


def read_meta(sample, quant_dir):
    path = quant_dir / "aux_info" / "meta_info.json"
    if not path.is_file():
        raise FileNotFoundError(f"missing Salmon meta_info.json for sample '{sample}': {path}")
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise ValueError(f"malformed Salmon meta_info.json for sample '{sample}': {path}: {exc}") from exc


def read_fastq_pairs(path):
    counts = {}
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            sample = row["sample"]
            counts[sample] = counts.get(sample, 0) + 1
    if not counts:
        raise ValueError(f"normalized samplesheet is empty: {path}")
    return counts


def make_row(sample, fastq_pairs, quant_dir):
    meta = read_meta(sample, quant_dir)
    for key in ("num_processed", "num_mapped"):
        if not isinstance(meta.get(key), (int, float)):
            raise ValueError(f"sample '{sample}' is missing native Salmon field '{key}'")
    return {
        "sample": sample,
        "num_processed": value(meta, "num_processed"),
        "num_mapped": value(meta, "num_mapped"),
        "percent_mapped": value(meta, "percent_mapped"),
        "detected_library_type": value(meta, "detected_library_type"),
        "frag_length_mean": value(meta, "frag_length_mean"),
        "frag_length_sd": value(meta, "frag_length_sd"),
        "salmon_version": value(meta, "salmon_version"),
        "fastq_pairs": fastq_pairs,
    }


def main():
    parser = argparse.ArgumentParser(description="Export native Salmon and tximport summary metrics.")
    parser.add_argument("--quant-dirs", type=Path, nargs="+", required=True)
    parser.add_argument("--samplesheet", type=Path, required=True)
    parser.add_argument("--sample-count-summary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--multiqc-general", type=Path, required=True)
    args = parser.parse_args()

    try:
        fastq_pairs = read_fastq_pairs(args.samplesheet)
        quant_dirs = {path.name: path for path in args.quant_dirs}
        missing = sorted(set(fastq_pairs) - set(quant_dirs))
        extra = sorted(set(quant_dirs) - set(fastq_pairs))
        if missing or extra:
            details = []
            if missing:
                details.append(f"missing quantification directory for: {', '.join(missing)}")
            if extra:
                details.append(f"unexpected quantification directory for: {', '.join(extra)}")
            raise ValueError("; ".join(details))
        rows = [make_row(sample, fastq_pairs[sample], quant_dirs[sample]) for sample in sorted(fastq_pairs)]
        with args.output.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)

        with args.sample_count_summary.open(newline="", encoding="utf-8") as handle:
            summary = {row["sample"]: row for row in csv.DictReader(handle, delimiter="\t")}
        missing_summary = sorted(set(fastq_pairs) - set(summary))
        if missing_summary:
            raise ValueError(f"sample summary missing sample(s): {', '.join(missing_summary)}")
        headers = [
            {"estimated_library": {"title": "Estimated library", "description": "Sum of tximport estimated counts", "format": "{:,.3f}"}},
            {"detected_genes": {"title": "Detected genes", "description": "Genes with estimated count greater than zero", "format": "{:,.0f}"}},
        ]
        data = {
            sample: {
                "estimated_library": float(summary[sample]["total_estimated_fragments"]),
                "detected_genes": int(summary[sample]["genes_with_estimated_count_gt_0"]),
            }
            for sample in sorted(fastq_pairs)
        }
        args.multiqc_general.write_text(json.dumps({
            "id": "sns_rna_qc", "section_name": "Pipeline RNA QC", "plot_type": "generalstats",
            "headers": headers, "data": data,
        }, indent=2) + "\n", encoding="utf-8")
    except (OSError, KeyError, TypeError, ValueError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()
