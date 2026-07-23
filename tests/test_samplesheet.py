from __future__ import annotations

import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args: str, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, text=True, capture_output=True)


def touch(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("")


def test_make_samplesheet_supported_patterns(tmp_path: Path) -> None:
    for name in [
        "UDB001_R1.fastq.gz",
        "UDB001_R2.fastq.gz",
        "UDB002_L001_R1.fq.gz",
        "UDB002_L001_R2.fq.gz",
    ]:
        touch(tmp_path / name)

    out = tmp_path / "samplesheet.csv"
    result = run(sys.executable, "scripts/make_samplesheet.py", str(tmp_path), "-o", str(out))

    assert result.returncode == 0, result.stderr
    rows = list(csv.DictReader(out.open()))
    assert [row["sample"] for row in rows] == ["UDB001", "UDB002_L001"]


def test_make_samplesheet_duplicate_pair_fails(tmp_path: Path) -> None:
    for name in ["S1_R1.fastq.gz", "S1_1.fastq.gz", "S1_R2.fastq.gz"]:
        touch(tmp_path / name)

    result = run(sys.executable, "scripts/make_samplesheet.py", str(tmp_path))

    assert result.returncode != 0
    assert "Duplicate R1" in result.stderr


def test_validate_samplesheet_accepts_csv_and_tsv(tmp_path: Path) -> None:
    r1 = tmp_path / "S1_R1.fastq.gz"
    r2 = tmp_path / "S1_R2.fastq.gz"
    touch(r1)
    touch(r2)
    sheet = tmp_path / "samplesheet.tsv"
    sheet.write_text(f"sample\tfastq_1\tfastq_2\nS1\t{r1}\t{r2}\n")

    result = run(sys.executable, "scripts/validate_samplesheet.py", str(sheet), "--json")

    assert result.returncode == 0, result.stderr
    assert '"sample": "S1"' in result.stdout


def test_validate_samplesheet_rejects_unsafe_sample(tmp_path: Path) -> None:
    r1 = tmp_path / "S1_R1.fastq.gz"
    r2 = tmp_path / "S1_R2.fastq.gz"
    touch(r1)
    touch(r2)
    sheet = tmp_path / "samplesheet.csv"
    sheet.write_text(f"sample,fastq_1,fastq_2\nbad/sample,{r1},{r2}\n")

    result = run(sys.executable, "scripts/validate_samplesheet.py", str(sheet))

    assert result.returncode != 0
    assert "Unsafe sample ID" in result.stderr
