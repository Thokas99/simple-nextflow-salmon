#!/usr/bin/env python3
"""Create a tiny artificial paired-end dataset long enough for Salmon k=31."""

import csv
import gzip
import sys
from pathlib import Path


root = Path(sys.argv[1]).resolve()
fastqs = root / "fastqs"
reference = root / "reference" / "raw"
fastqs.mkdir(parents=True, exist_ok=True)
reference.mkdir(parents=True, exist_ok=True)

transcript = ("ACGTTGCAAGTCCTGACTGA" * 30)[:600]
genome = "N" * 100 + transcript + "N" * 100
with gzip.open(reference / "gencode.v50.transcripts.fa.gz", "wt") as handle:
    handle.write(f">ENST_SYNTHETIC.1\n{transcript}\n")
with gzip.open(reference / "GRCh38.p14.genome.fa.gz", "wt") as handle:
    handle.write(f">chrSynthetic\n{genome}\n")
with gzip.open(reference / "gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz", "wt") as handle:
    handle.write('chrSynthetic\ttest\ttranscript\t101\t700\t.\t+\t.\tgene_id "ENSG_SYNTHETIC.1"; transcript_id "ENST_SYNTHETIC.1"; gene_name "SYNTH"; gene_type "protein_coding";\n')

rows = []
for lane, offset in ((1, 0), (2, 20)):
    r1 = fastqs / f"Synthetic_S1_L{lane:03d}_R1_001.fastq.gz"
    r2 = fastqs / f"Synthetic_S1_L{lane:03d}_R2_001.fastq.gz"
    with gzip.open(r1, "wt") as one, gzip.open(r2, "wt") as two:
        for index in range(20):
            start = offset + index
            read1 = transcript[start:start + 75]
            read2 = transcript[start + 125:start + 200][::-1].translate(str.maketrans("ACGT", "TGCA"))
            one.write(f"@synthetic_{lane}_{index}/1\n{read1}\n+\n{'I' * len(read1)}\n")
            two.write(f"@synthetic_{lane}_{index}/2\n{read2}\n+\n{'I' * len(read2)}\n")
    rows.append(["Synthetic", str(r1), str(r2)])

with (root / "samplesheet.csv").open("w", newline="") as handle:
    writer = csv.writer(handle, quoting=csv.QUOTE_ALL)
    writer.writerow(["sample", "fastq_1", "fastq_2"])
    writer.writerows(rows)
