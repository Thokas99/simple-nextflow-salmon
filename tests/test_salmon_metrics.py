#!/usr/bin/env python3

import csv
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "salmon_metrics.py"


class SalmonMetricsTest(unittest.TestCase):
    def run_metrics(self, meta, counts):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        count_paths = []
        for sample, (input_fragments, fastq_pairs) in counts.items():
            path = root / f"{sample}.counts.tsv"
            path.write_text(f"sample\tinput_fragments\tfastq_pairs\n{sample}\t{input_fragments}\t{fastq_pairs}\n")
            count_paths.append(path)
        for sample, content in meta.items():
            aux = root / sample / "aux_info"
            aux.mkdir(parents=True)
            (aux / "meta_info.json").write_text(json.dumps(content))
        output = root / "salmon_metrics.tsv"
        result = subprocess.run(
            ["python3", str(SCRIPT), "--input-counts", *map(str, count_paths), "--quant-dirs",
             *[str(root / sample) for sample in meta], "--quant-output-dir", "results/salmon",
             "--output", str(output), "--counts-output", str(root / "input_fragment_counts.tsv"),
             "--multiqc-general", str(root / "salmon2_qc_general_mqc.json"),
             "--multiqc-details", str(root / "salmon2_qc_details_mqc.json")],
            text=True, capture_output=True,
        )
        if result.returncode:
            return result, None, root
        with output.open(newline="") as handle:
            return result, list(csv.DictReader(handle, delimiter="\t")), root

    @staticmethod
    def meta(aligned, quantified):
        return {"num_processed": aligned, "num_mapped": quantified, "percent_mapped": 100 * quantified / aligned if aligned else 0,
                "detected_library_type": "ISR", "frag_length_mean": 250.5,
                "frag_length_sd": 40.2, "salmon_version": "2.3.4"}

    def test_single_lane_and_rate_mathematics(self):
        result, rows, root = self.run_metrics({"S1": self.meta(800, 720)}, {"S1": (1000, 1)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(rows[0]["input_fragments"], "1000")
        self.assertEqual(rows[0]["aligned_fragments"], "800")
        self.assertEqual(rows[0]["quantified_fragments"], "720")
        self.assertEqual(float(rows[0]["alignment_rate"]), 80)
        self.assertEqual(float(rows[0]["quantification_rate"]), 72)
        self.assertEqual(float(rows[0]["compatibility_rate"]), 90)
        self.assertEqual(rows[0]["fastq_pairs"], "1")
        general = json.loads((root / "salmon2_qc_general_mqc.json").read_text())
        self.assertEqual([next(iter(item.values()))["title"] for item in general["headers"]], ["Align %", "Quant %", "Compat %"])

    def test_multiple_lanes_are_not_double_counted(self):
        result, rows, _ = self.run_metrics({"A": self.meta(240, 210)}, {"A": (300, 2)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(rows[0]["input_fragments"], "300")
        self.assertEqual(rows[0]["fastq_pairs"], "2")

    def test_very_poor_sample_is_valid(self):
        result, rows, _ = self.run_metrics({"FFPE": self.meta(100000, 90000)}, {"FFPE": (10000000, 1)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(float(rows[0]["alignment_rate"]), 1)

    def test_zero_denominators_are_zero(self):
        result, rows, _ = self.run_metrics({"S1": self.meta(0, 0)}, {"S1": (0, 1)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([float(rows[0][key]) for key in ("alignment_rate", "quantification_rate", "compatibility_rate")], [0, 0, 0])

    def test_impossible_states_fail(self):
        for meta, count, message in ((self.meta(1001, 720), 1000, "aligned_fragments"),
                                     (self.meta(800, 801), 1000, "quantified_fragments")):
            with self.subTest(message=message):
                result, _, _ = self.run_metrics({"S1": meta}, {"S1": (count, 1)})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)

    def test_wrong_salmon_version_fails(self):
        meta = self.meta(8, 7)
        meta["salmon_version"] = "1.10.3"
        result, _, _ = self.run_metrics({"S1": meta}, {"S1": (10, 1)})
        self.assertIn("QC semantics require Salmon 2.3.4", result.stderr)


if __name__ == "__main__":
    unittest.main()
