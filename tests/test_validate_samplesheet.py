import csv
import gzip
import tempfile
import unittest
from pathlib import Path

from scripts.validate_samplesheet import discover, validate, write_outputs


class ValidateSamplesheetTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write_fastq(self.root / "A,R1.fastq", "A001/1")
        self.write_fastq(self.root / "A,R2.fastq", "A001/2")
        self.write_fastq(self.root / "B_R1.fastq.gz", "B001/1")
        self.write_fastq(self.root / "B_R2.fastq.gz", "B001/2")

    @staticmethod
    def write_fastq(path, identifier, sequence="ACGT"):
        opener = gzip.open if path.name.endswith(".gz") else open
        with opener(path, "wt") as handle:
            handle.write(f"@{identifier}\n{sequence}\n+\n{'I' * len(sequence)}\n")

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

    def test_mgi_discovery_writes_deterministic_normalized_csv(self):
        fastqs = self.root / "fastqs"
        fastqs.mkdir()
        for lane in (2, 1):
            self.write_fastq(fastqs / f"V350387909_L{lane:02d}_UDB001_1.fq.gz", f"UDB001_{lane}/1")
            self.write_fastq(fastqs / f"V350387909_L{lane:02d}_UDB001_2.fq.gz", f"UDB001_{lane}/2")
        result = discover(fastqs, "mgi", self.root / "fastqs")
        output = self.root / "resolved_samplesheet.csv"
        write_outputs(result, output, self.root / "resolved_samplesheet.json")
        self.assertEqual(output.read_text().splitlines()[1].split(",")[0], '"UDB001"')
        self.assertIn("L01", output.read_text().splitlines()[1])

    def test_rejects_zero_byte_fastq(self):
        (self.root / "empty.fastq").touch()
        path = self.write([["A", "empty.fastq", "A,R2.fastq"]])
        with self.assertRaisesRegex(ValueError, "file is empty"):
            validate(path, self.root)

    def test_rejects_malformed_first_fastq_record(self):
        malformed = self.root / "malformed.fastq"
        malformed.write_text("not-a-header\nACGT\n+\nIIII\n")
        path = self.write([["A", "malformed.fastq", "A,R2.fastq"]])
        with self.assertRaisesRegex(ValueError, "header must start"):
            validate(path, self.root)

    def test_rejects_mismatched_first_mate_ids(self):
        self.write_fastq(self.root / "different.fastq", "other/2")
        path = self.write([["A", "A,R1.fastq", "different.fastq"]])
        with self.assertRaisesRegex(ValueError, "identifiers differ"):
            validate(path, self.root)


if __name__ == "__main__":
    unittest.main()
