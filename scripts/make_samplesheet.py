#!/usr/bin/env python3
"""Create a lane-aware SnS samplesheet from paired-end FASTQs."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


EXT = r"\.f(?:ast)?q(?:\.gz)?"
ILLUMINA_RE = re.compile(
    rf"^(?P<sample>.+)_S(?P<sample_no>\d+)_L(?P<lane>\d{{3}})_R(?P<read>[12])_(?P<chunk>\d{{3}})(?P<ext>{EXT})$",
    re.IGNORECASE,
)
SIMPLE_RE = re.compile(rf"^(?P<sample>.+?)[_.-]R(?P<read>[12])(?P<ext>{EXT})$", re.IGNORECASE)
FASTQ_EXT_RE = re.compile(rf"{EXT}$", re.IGNORECASE)
SAFE_SAMPLE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")


@dataclass(frozen=True)
class ParsedFastq:
    path: Path
    sample: str
    read: int
    lane: int | None
    chunk: int | None
    style: str

    @property
    def pair_key(self) -> tuple[str, int, int]:
        return (self.sample, self.lane or 0, self.chunk or 0)


def parse_fastq(path: Path) -> ParsedFastq:
    match = ILLUMINA_RE.fullmatch(path.name)
    if match:
        return ParsedFastq(
            path.resolve(), match["sample"], int(match["read"]), int(match["lane"]),
            int(match["chunk"]), "illumina",
        )
    match = SIMPLE_RE.fullmatch(path.name)
    if match:
        sample = match["sample"]
        if re.search(r"(?:^|[_-])(?:S\d+|L\d{3})(?:[_-]|$)", sample, re.IGNORECASE):
            raise ValueError(
                f"ambiguous FASTQ name '{path.name}': Illumina S/L tokens require the complete "
                "'<sample>_S<number>_L<lane>_R<read>_<chunk>' form"
            )
        return ParsedFastq(path.resolve(), sample, int(match["read"]), None, None, "simple")
    raise ValueError(
        f"ambiguous FASTQ name '{path.name}': expected '<sample>_R1.fastq.gz' or "
        "'<sample>_S1_L001_R1_001.fastq.gz' (and the matching R2)"
    )


def find_fastqs(fastq_dir: Path) -> list[ParsedFastq]:
    candidates = sorted(
        (path for path in fastq_dir.rglob("*") if path.is_file() and FASTQ_EXT_RE.search(path.name)),
        key=lambda path: str(path.resolve()),
    )
    parsed: list[ParsedFastq] = []
    errors: list[str] = []
    basenames: dict[str, Path] = {}
    for path in candidates:
        previous = basenames.get(path.name)
        if previous and previous.resolve() != path.resolve():
            errors.append(f"basename collision '{path.name}': {previous} and {path}")
        else:
            basenames[path.name] = path
        try:
            parsed.append(parse_fastq(path))
        except ValueError as exc:
            errors.append(str(exc))
    if errors:
        raise ValueError("FASTQ discovery failed:\n- " + "\n- ".join(errors))
    return parsed


def build_rows(fastqs: list[ParsedFastq], lanes_as_samples: bool = False) -> list[dict[str, str]]:
    pairs: dict[tuple[str, int, int], dict[int, ParsedFastq]] = defaultdict(dict)
    errors: list[str] = []
    styles: dict[str, set[str]] = defaultdict(set)
    for fastq in fastqs:
        styles[fastq.sample].add(fastq.style)
        mate = pairs[fastq.pair_key]
        if fastq.read in mate:
            errors.append(
                f"duplicate R{fastq.read} for sample '{fastq.sample}' lane "
                f"{fastq.lane or 'none'}: {mate[fastq.read].path} and {fastq.path}"
            )
        else:
            mate[fastq.read] = fastq
    for sample, sample_styles in styles.items():
        if len(sample_styles) > 1:
            errors.append(f"ambiguous naming for sample '{sample}': mixes simple and Illumina lane formats")
    for key, mates in pairs.items():
        if set(mates) != {1, 2}:
            missing = 2 if 1 in mates else 1
            errors.append(f"missing R{missing} mate for sample '{key[0]}' lane {key[1] or 'none'} chunk {key[2] or 'none'}")
    if errors:
        raise ValueError("FASTQ pairing failed:\n- " + "\n- ".join(errors))

    rows = []
    for (sample, lane, chunk), mates in sorted(pairs.items()):
        output_sample = f"{sample}_L{lane:03d}" if lanes_as_samples and lane else sample
        if not SAFE_SAMPLE_RE.fullmatch(output_sample):
            raise ValueError(f"unsafe sample identifier derived from filename: '{output_sample}'")
        rows.append({"sample": output_sample, "fastq_1": str(mates[1].path), "fastq_2": str(mates[2].path)})
    return rows


def write_csv(rows: list[dict[str, str]], output: Path, overwrite: bool) -> None:
    if output.exists() and not overwrite:
        raise FileExistsError(f"samplesheet already exists: {output} (use --overwrite to replace it)")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=["sample", "fastq_1", "fastq_2"], quoting=csv.QUOTE_ALL, lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Create a lane-aware sample,fastq_1,fastq_2 CSV.")
    parser.add_argument("fastq_dir", type=Path, help="Directory searched recursively for FASTQs")
    parser.add_argument("-o", "--out", type=Path, default=Path("samplesheet.csv"))
    parser.add_argument("--lanes-as-samples", action="store_true", help="Treat detected Illumina lanes as separate samples")
    parser.add_argument("--dry-run", action="store_true", help="Print the CSV without writing it")
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing output samplesheet")
    args = parser.parse_args(argv)
    try:
        if not args.fastq_dir.is_dir():
            raise ValueError(f"FASTQ directory does not exist: {args.fastq_dir}")
        fastqs = find_fastqs(args.fastq_dir)
        if not fastqs:
            raise ValueError(f"no FASTQ files found under: {args.fastq_dir}")
        rows = build_rows(fastqs, args.lanes_as_samples)
        samples = list(dict.fromkeys(row["sample"] for row in rows))
        technical = sum(sum(row["sample"] == sample for row in rows) > 1 for sample in samples)
        if args.dry_run:
            writer = csv.DictWriter(sys.stdout, fieldnames=["sample", "fastq_1", "fastq_2"], quoting=csv.QUOTE_ALL, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
            destination = "dry-run (not written)"
        else:
            write_csv(rows, args.out, args.overwrite)
            destination = str(args.out.resolve())
        print(
            f"Biological samples: {len(samples)}; FASTQ pairs: {len(rows)}; "
            f"technical-replicate samples: {technical}; output: {destination}", file=sys.stderr
        )
        return 0
    except (OSError, ValueError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
