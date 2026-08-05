#!/usr/bin/env python3

import argparse
import csv
import subprocess
from pathlib import Path


def seqkit_counts(paths):
    result = subprocess.run(
        ["seqkit", "stats", "--tabular", *map(str, paths)],
        check=True,
        text=True,
        capture_output=True,
    )
    rows = list(csv.DictReader(result.stdout.splitlines(), delimiter="\t"))
    if len(rows) != len(paths) or any("num_seqs" not in row for row in rows):
        raise ValueError("seqkit stats returned an unexpected table")
    return [int(row["num_seqs"].replace(",", "")) for row in rows]


def summarize(sample, r1, r2, counts):
    if len(r1) != len(r2):
        raise ValueError(f"sample '{sample}' has {len(r1)} R1 files but {len(r2)} R2 files")
    r1_counts, r2_counts = counts[:len(r1)], counts[len(r1):]
    for index, (one, two) in enumerate(zip(r1_counts, r2_counts), 1):
        if one != two:
            raise ValueError(
                f"sample '{sample}' FASTQ pair {index} has mismatched records: R1={one}, R2={two}"
            )
    return {"sample": sample, "input_fragments": sum(r1_counts), "fastq_pairs": len(r1)}


def main():
    parser = argparse.ArgumentParser(description="Count paired-end input fragments with seqkit.")
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", type=Path, nargs="+", required=True)
    parser.add_argument("--r2", type=Path, nargs="+", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        row = summarize(args.sample, args.r1, args.r2, seqkit_counts([*args.r1, *args.r2]))
        with args.output.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=row, delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerow(row)
    except (OSError, subprocess.CalledProcessError, ValueError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()
