#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "input_fragment_counts.py"
SPEC = importlib.util.spec_from_file_location("input_fragment_counts", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class InputFragmentCountsTest(unittest.TestCase):
    def test_multiple_lanes_count_r1_once(self):
        row = MODULE.summarize("A", [Path("L1_R1"), Path("L2_R1")], [Path("L1_R2"), Path("L2_R2")], [100, 200, 100, 200])
        self.assertEqual(row, {"sample": "A", "input_fragments": 300, "fastq_pairs": 2})

    def test_mismatched_pair_fails_clearly(self):
        with self.assertRaisesRegex(ValueError, "mismatched records: R1=100, R2=99"):
            MODULE.summarize("A", [Path("R1")], [Path("R2")], [100, 99])


if __name__ == "__main__":
    unittest.main()
