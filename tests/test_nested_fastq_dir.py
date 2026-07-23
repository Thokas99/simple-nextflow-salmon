import csv
import subprocess
import sys
from pathlib import Path


def test_make_samplesheet_scans_nested_fastq_dir(tmp_path: Path) -> None:
    fastq_dir = tmp_path / "fastq2" / "FASTQ"
    fastq_dir.mkdir(parents=True)
    (fastq_dir / "UDB001_R1.fastq.gz").write_text("")
    (fastq_dir / "UDB001_R2.fastq.gz").write_text("")

    out = tmp_path / "fastq2" / "samplesheet.csv"
    subprocess.run(
        [sys.executable, "scripts/make_samplesheet.py", str(tmp_path / "fastq2"), "-o", str(out)],
        check=True,
    )

    rows = list(csv.DictReader(out.open()))
    assert rows == [
        {
            "sample": "UDB001",
            "fastq_1": str((fastq_dir / "UDB001_R1.fastq.gz").resolve()),
            "fastq_2": str((fastq_dir / "UDB001_R2.fastq.gz").resolve()),
        }
    ]
