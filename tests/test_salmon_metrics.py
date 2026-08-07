#!/usr/bin/env python3

import csv
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "salmon_metrics.py"


class SalmonMetricsTest(unittest.TestCase):
    def run_metrics(self, meta, pairs):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        samplesheet = root / "resolved_samplesheet.csv"
        with samplesheet.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=["sample", "fastq_1", "fastq_2"])
            writer.writeheader()
            for sample, count in pairs.items():
                for lane in range(count):
                    writer.writerow({"sample": sample, "fastq_1": f"{sample}_{lane}_R1.fastq", "fastq_2": f"{sample}_{lane}_R2.fastq"})
        summary = root / "sample_count_summary.tsv"
        summary.write_text("sample\ttotal_estimated_fragments\tgenes_with_estimated_count_gt_0\n" + "".join(
            f"{sample}\t{count * 10.5}\t{count + 2}\n" for sample, count in pairs.items()
        ))
        for sample, content in meta.items():
            aux = root / sample / "aux_info"
            aux.mkdir(parents=True)
            (aux / "meta_info.json").write_text(json.dumps(content))
        output = root / "salmon_metrics.tsv"
        custom = root / "pipeline_rna_qc_mqc.json"
        result = subprocess.run(
            ["python3", str(SCRIPT), "--samplesheet", str(samplesheet), "--sample-count-summary", str(summary),
             "--quant-dirs", *[str(root / sample) for sample in meta], "--output", str(output),
             "--multiqc-general", str(custom)], text=True, capture_output=True,
        )
        if result.returncode == 0:
            with output.open(newline="") as handle:
                rows = list(csv.DictReader(handle, delimiter="\t"))
        else:
            rows = None
        return result, rows, custom

    @staticmethod
    def meta(processed, mapped):
        return {"num_processed": processed, "num_mapped": mapped, "percent_mapped": 90.0,
                "detected_library_type": "ISR", "frag_length_mean": 250.5,
                "frag_length_sd": 40.2, "salmon_version": "2.3.4"}

    def test_native_salmon_fields_are_copied_without_relabeling(self):
        result, rows, custom = self.run_metrics({"S1": self.meta(800, 720)}, {"S1": 2})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(rows[0]["num_processed"], "800")
        self.assertEqual(rows[0]["num_mapped"], "720")
        self.assertEqual(rows[0]["percent_mapped"], "90.0")
        self.assertNotIn("alignment_rate", rows[0])
        self.assertEqual(rows[0]["fastq_pairs"], "2")
        data = json.loads(custom.read_text())
        self.assertEqual([next(iter(item.values()))["title"] for item in data["headers"]], ["Estimated library", "Detected genes"])

    def test_missing_native_field_fails(self):
        meta = self.meta(800, 720)
        del meta["num_mapped"]
        result, _, _ = self.run_metrics({"S1": meta}, {"S1": 1})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("num_mapped", result.stderr)


if __name__ == "__main__":
    unittest.main()
