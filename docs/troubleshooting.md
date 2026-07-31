# Troubleshooting

| Message or symptom | Resolution |
|---|---|
| `ambiguous FASTQ name` | Use a complete supported naming pattern; do not infer lanes manually |
| `basename collision` | Make FASTQ basenames globally unique in the samplesheet |
| `shell-sensitive characters` | Move inputs/outputs to paths without quotes, control characters, `$`, backticks, or shell operators |
| Cache will be built unexpectedly | Inspect `reference_manifest.json`; source bytes, Salmon, k, or reference release changed |
| Existing immutable cache during publication | Another run won the atomic publication; rerun with `-resume` after confirming that entry validates |
| Transcript overlap too low | Confirm the quantification reference and GTF are the same GENCODE release |
| Non-finite tximport matrix | Inspect malformed/empty `quant.sf` files and Salmon logs |
