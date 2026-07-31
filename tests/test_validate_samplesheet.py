import csv
import tempfile
import unittest
from pathlib import Path

from scripts.validate_samplesheet import validate


class ValidateSamplesheetTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("A,R1.fastq", "A,R2.fastq", "B_R1.fastq.gz", "B_R2.fastq.gz"):
            (self.root / name).touch()

    def write(self, rows, header=("sample", "fastq_1", "fastq_2")):
        path = self.root / "samples.csv"
        with path.open("w", newline="") as handle:
            writer = csv.writer(handle, quoting=csv.QUOTE_ALL)
            writer.writerow(header)
            writer.writerows(rows)
        return path

    def test_quoted_csv_and_ordered_replicates(self):
        path = self.write([["A", "A,R1.fastq", "A,R2.fastq"], ["B", "B_R1.fastq.gz", "B_R2.fastq.gz"]])
        result = validate(path, self.root)
        self.assertEqual([sample["sample"] for sample in result["samples"]], ["A", "B"])

    def test_accumulates_invalid_input_errors(self):
        path = self.write([["bad sample", "missing.txt", "missing.txt"]])
        with self.assertRaises(ValueError) as raised:
            validate(path, self.root)
        message = str(raised.exception)
        self.assertIn("unsafe identifier", message)
        self.assertIn("unsupported FASTQ extension", message)
        self.assertIn("same file", message)

    def test_exact_header_empty_data_duplicate_and_collision(self):
        with self.assertRaises(ValueError):
            validate(self.write([], ("sample", "fastq_1", "wrong")), self.root)
        path = self.write([["A", "B_R1.fastq.gz", "B_R2.fastq.gz"], ["A", "B_R1.fastq.gz", "B_R2.fastq.gz"]])
        with self.assertRaisesRegex(ValueError, "repeated within sample"):
            validate(path, self.root)


if __name__ == "__main__":
    unittest.main()
