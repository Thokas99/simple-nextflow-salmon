#!/usr/bin/env python3

import csv
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "salmon_metrics.py"


class SalmonMetricsTest(unittest.TestCase):
    def run_metrics(self, meta, rows):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        samplesheet = root / "samples.csv"
        with samplesheet.open("w", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["sample", "fastq_1", "fastq_2"])
            writer.writerows(rows)
        for sample, content in meta.items():
            aux = root / sample / "aux_info"
            aux.mkdir(parents=True)
            (aux / "meta_info.json").write_text(json.dumps(content))
        output = root / "salmon_metrics.tsv"
        subprocess.run(
            ["python3", str(SCRIPT), "--samplesheet", str(samplesheet), "--quant-dirs",
             *[str(root / sample) for sample in meta], "--quant-output-dir", "results/salmon",
             "--output", str(output)],
            check=True,
        )
        with output.open(newline="") as handle:
            return list(csv.DictReader(handle, delimiter="\t"))

    def test_complete_metrics_and_lane_count(self):
        rows = self.run_metrics(
            {"S1": {"num_processed": 100, "num_mapped": 80, "percent_mapped": 80.0,
                    "detected_library_type": "ISR", "frag_length_mean": 250.5,
                    "frag_length_sd": 40.2, "salmon_version": "2.3.4"}},
            [["S1", "L1_R1.fastq.gz", "L1_R2.fastq.gz"],
             ["S1", "L2_R1.fastq.gz", "L2_R2.fastq.gz"]],
        )
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["fastq_pairs"], "2")
        self.assertEqual(rows[0]["mapping_rate"], "80.0")

    def test_optional_fields_may_be_missing(self):
        rows = self.run_metrics(
            {"S1": {"num_processed": 10, "num_mapped": 5}},
            [["S1", "R1.fastq.gz", "R2.fastq.gz"]],
        )
        self.assertEqual(rows[0]["mapping_rate"], "50.0")
        self.assertEqual(rows[0]["frag_length_mean"], "")
        self.assertEqual(rows[0]["salmon_version"], "")

    def run_failure(self, meta_text=None, sample="S1", quant_sample="S1"):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        samplesheet = root / "samples.csv"
        samplesheet.write_text(f"sample,fastq_1,fastq_2\n{sample},R1.fastq,R2.fastq\n")
        aux = root / quant_sample / "aux_info"
        aux.mkdir(parents=True)
        if meta_text is not None:
            (aux / "meta_info.json").write_text(meta_text)
        return subprocess.run(
            ["python3", str(SCRIPT), "--samplesheet", str(samplesheet), "--quant-dirs", str(root / quant_sample),
             "--quant-output-dir", "results/salmon", "--output", str(root / "out.tsv")],
            text=True, capture_output=True,
        )

    def test_missing_and_malformed_metadata_fail(self):
        self.assertIn("missing Salmon meta_info.json", self.run_failure().stderr)
        self.assertIn("malformed Salmon meta_info.json", self.run_failure("{bad").stderr)

    def test_quant_directory_mismatch_fails(self):
        result = self.run_failure("{}", sample="S1", quant_sample="other")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing quantification directory for: S1", result.stderr)
        self.assertIn("unexpected quantification directory for: other", result.stderr)


if __name__ == "__main__":
    unittest.main()
