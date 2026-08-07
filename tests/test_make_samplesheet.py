#!/usr/bin/env python3

import csv
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.make_samplesheet import build_rows, find_fastqs


SCRIPT = Path(__file__).parents[1] / "scripts" / "make_samplesheet.py"


class MakeSamplesheetTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def touch(self, *names):
        for name in names:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()

    def test_illumina_lanes_group_in_lane_order(self):
        self.touch(*[f"Patient01_S1_L00{lane}_R{read}_001.fastq.gz" for lane in (2, 1) for read in (1, 2)])
        rows = build_rows(find_fastqs(self.root))
        self.assertEqual([row["sample"] for row in rows], ["Patient01", "Patient01"])
        self.assertIn("L001_R1", rows[0]["fastq_1"])

    def test_simple_names_and_extensions_nested(self):
        for ext in ("fastq", "fastq.gz", "fq", "fq.gz"):
            self.touch(f"nested/S{ext.replace('.', '_')}_R1.{ext}", f"nested/S{ext.replace('.', '_')}_R2.{ext}")
        self.assertEqual(len(build_rows(find_fastqs(self.root))), 4)

    def test_lanes_as_samples(self):
        self.touch("P_S1_L001_R1_001.fq", "P_S1_L001_R2_001.fq")
        self.assertEqual(build_rows(find_fastqs(self.root), True)[0]["sample"], "P_L001")

    def test_mgi_lanes_group_by_biological_sample(self):
        self.touch(
            "V350387909_L01_UDB001_1.fq.gz", "V350387909_L01_UDB001_2.fq.gz",
            "V350387909_L02_UDB001_1.fq.gz", "V350387909_L02_UDB001_2.fq.gz",
        )
        rows = build_rows(find_fastqs(self.root, "mgi"))
        self.assertEqual([row["sample"] for row in rows], ["UDB001", "UDB001"])
        self.assertIn("L01", rows[0]["fastq_1"])

    def test_explicit_naming_rejects_other_conventions(self):
        self.touch("P_R1.fastq.gz", "P_R2.fastq.gz")
        with self.assertRaises(ValueError):
            find_fastqs(self.root, "illumina")

    def test_missing_duplicate_collision_and_ambiguous_fail(self):
        cases = [
            ("missing", ["P_R1.fastq"]),
            ("collision", ["a/P_R1.fastq", "a/P_R2.fastq", "b/P_R1.fastq", "b/P_R2.fastq"]),
            ("ambiguous", ["P_L001_R1.fastq", "P_L001_R2.fastq"]),
        ]
        for name, files in cases:
            with self.subTest(name=name):
                root = self.root / name
                root.mkdir()
                for file in files:
                    path = root / file
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.touch()
                with self.assertRaises(ValueError):
                    build_rows(find_fastqs(root))

    def test_dry_run_quoted_csv_and_no_overwrite(self):
        self.touch("P_R1.fastq.gz", "P_R2.fastq.gz")
        result = subprocess.run(["python3", str(SCRIPT), str(self.root), "--dry-run"], text=True, capture_output=True, check=True)
        self.assertEqual(next(csv.reader(result.stdout.splitlines())), ["sample", "fastq_1", "fastq_2"])
        self.assertTrue(result.stdout.startswith('"sample","fastq_1","fastq_2"'))
        output = self.root / "samples.csv"
        subprocess.run(["python3", str(SCRIPT), str(self.root), "-o", str(output)], check=True)
        failed = subprocess.run(["python3", str(SCRIPT), str(self.root), "-o", str(output)], capture_output=True)
        self.assertNotEqual(failed.returncode, 0)


if __name__ == "__main__":
    unittest.main()
