#!/usr/bin/env python3

import argparse
import csv
import json
import sys
from pathlib import Path


FIELDS = [
    "sample",
    "input_fragments",
    "aligned_fragments",
    "alignment_rate",
    "quantified_fragments",
    "quantification_rate",
    "compatibility_rate",
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


def read_counts(paths):
    counts = {}
    for path in paths:
        with path.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
        if len(rows) != 1 or set(rows[0]) != {"sample", "input_fragments", "fastq_pairs"}:
            raise ValueError(f"invalid input-fragment count table: {path}")
        row = rows[0]
        sample = row["sample"]
        if sample in counts:
            raise ValueError(f"duplicate input-fragment count for sample '{sample}'")
        counts[sample] = {"input_fragments": int(row["input_fragments"]), "fastq_pairs": int(row["fastq_pairs"])}
    if not counts:
        raise ValueError("no input-fragment counts were provided")
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


def rate(numerator, denominator):
    return 0.0 if denominator == 0 else 100.0 * numerator / denominator


def make_row(sample, input_count, quant_dir, quant_output_dir):
    meta = read_meta(sample, quant_dir)
    version = str(meta.get("salmon_version", ""))
    if version != "2.3.4":
        raise ValueError(f"sample '{sample}' reports Salmon {version or 'unknown'}; QC semantics require Salmon 2.3.4")
    input_fragments = input_count["input_fragments"]
    aligned = meta.get("num_processed")
    quantified = meta.get("num_mapped")
    if not isinstance(aligned, int) or not isinstance(quantified, int):
        raise ValueError(f"sample '{sample}' is missing integer Salmon 2.3.4 num_processed/num_mapped fields")
    if min(input_fragments, aligned, quantified) < 0:
        raise ValueError(f"sample '{sample}' has negative fragment counts")
    if aligned > input_fragments:
        raise ValueError(f"sample '{sample}' has aligned_fragments ({aligned}) > input_fragments ({input_fragments})")
    if quantified > aligned:
        raise ValueError(f"sample '{sample}' has quantified_fragments ({quantified}) > aligned_fragments ({aligned})")
    library_type = meta.get("detected_library_type")
    if library_type is None:
        library_types = meta.get("library_types") or []
        library_type = ",".join(map(str, library_types))
    alignment_rate = rate(aligned, input_fragments)
    quantification_rate = rate(quantified, input_fragments)
    compatibility_rate = rate(quantified, aligned)
    return {
        "sample": sample,
        "input_fragments": input_fragments,
        "aligned_fragments": aligned,
        "alignment_rate": alignment_rate,
        "quantified_fragments": quantified,
        "quantification_rate": quantification_rate,
        "compatibility_rate": compatibility_rate,
        "library_type": library_type or "",
        "frag_length_mean": value(meta, "frag_length_mean"),
        "frag_length_sd": value(meta, "frag_length_sd"),
        "salmon_version": version,
        "fastq_pairs": input_count["fastq_pairs"],
        "quantification_directory": str(quant_output_dir / sample),
    }


def main():
    parser = argparse.ArgumentParser(description="Combine per-sample Salmon meta_info.json metrics.")
    parser.add_argument("--input-counts", type=Path, nargs="+", required=True)
    parser.add_argument("--quant-dirs", type=Path, nargs="+", required=True)
    parser.add_argument("--quant-output-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--counts-output", type=Path, required=True)
    parser.add_argument("--multiqc-general", type=Path, required=True)
    parser.add_argument("--multiqc-details", type=Path, required=True)
    args = parser.parse_args()

    try:
        samples = read_counts(args.input_counts)
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
            make_row(sample, input_count, quant_dirs[sample], args.quant_output_dir)
            for sample, input_count in samples.items()
        ]
        library_types = {row["library_type"] for row in rows if row["library_type"]}
        if len(library_types) > 1:
            print(f"WARNING: inconsistent inferred library types: {', '.join(sorted(library_types))}", file=sys.stderr)
        with args.output.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
        with args.counts_output.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=["sample", "input_fragments", "fastq_pairs"], delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows({"sample": sample, **counts} for sample, counts in samples.items())
        general_headers = [
            {"alignment_rate": {"title": "Align %", "description": "Aligned fragments / input paired-end fragments × 100", "min": 0, "max": 100, "suffix": "%"}},
            {"quantification_rate": {"title": "Quant %", "description": "Quantified strand-compatible fragments / input paired-end fragments × 100", "min": 0, "max": 100, "suffix": "%"}},
            {"compatibility_rate": {"title": "Compat %", "description": "Quantified strand-compatible fragments / aligned fragments × 100", "min": 0, "max": 100, "suffix": "%"}},
        ]
        general = {"id": "salmon2_qc", "plot_type": "generalstats", "headers": general_headers,
                   "data": {row["sample"]: {key: row[key] for key in ("alignment_rate", "quantification_rate", "compatibility_rate")} for row in rows}}
        details_keys = ["input_fragments", "aligned_fragments", "quantified_fragments", "library_type", "frag_length_mean", "frag_length_sd", "salmon_version", "fastq_pairs"]
        details = {"id": "salmon2_qc_details", "section_name": "Salmon 2 QC details",
                   "description": "Fragment counts and provenance for Salmon 2.3.4. One paired R1/R2 record pair is one input fragment; technical lanes are summed per biological sample.",
                   "plot_type": "table", "data": {row["sample"]: {key: row[key] for key in details_keys} for row in rows}}
        args.multiqc_general.write_text(json.dumps(general, indent=2) + "\n", encoding="utf-8")
        args.multiqc_details.write_text(json.dumps(details, indent=2) + "\n", encoding="utf-8")
    except (OSError, ValueError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()
