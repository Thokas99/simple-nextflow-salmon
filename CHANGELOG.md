# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.0] - 2026-08-07

### Added

- Direct `--fastq_dir` input with conservative `auto`, Illumina, MGI, and simple pairing.
- Normalized `pipeline_info/resolved_samplesheet.csv` provenance for every run.
- Native Salmon MultiQC parsing and RNA-level estimated-library and detected-gene columns.

### Changed

- Salmon QC now reports native `meta_info.json` fields without relabeling or derived mapping rates.
- Technical lanes remain one Salmon quantification per biological sample while FastQC runs per pair.
- Conda/Micromamba is the documented execution path and CI/release runs use safe resource caps.

### Removed

- Redundant FASTQ fragment recounting and its QC denominator.
- Misleading custom Salmon alignment, quantification, and compatibility metrics.

## [0.3.1] - 2026-08-05

### Fixed

- Count paired-end input fragments explicitly with seqkit, validate R1/R2 record agreement, and sum technical lanes once per biological sample.
- Report Salmon 2.3.4 aligned and quantified strand-compatible fragments with explicit alignment, quantification, and compatibility rates and invariant checks.
- Replace misleading native Salmon legacy mapping labels in MultiQC with denominator-specific `Align %`, `Quant %`, and `Compat %` custom content.

### Compatibility

- Core Salmon quantification remains unchanged: Salmon 2.3.4, full-decoy selective alignment, automatic library detection, `--deterministic`, `--seqBias`, `--gcBias`, and tximport outputs are preserved.
- SnS 0.3.0 could display Salmon 2 compatibility statistics using legacy mapping terminology in MultiQC. This was a QC extraction/reporting problem, not evidence that quantification was incorrect.

## [0.3.0] - 2026-07-31

### Added

- Lane-aware, recursive samplesheet generation with preview, overwrite protection, and explicit lane-as-sample mode.
- Quoted-CSV validation, immutable SHA-256 reference caches, run provenance, Docker/Apptainer profiles, and real miniature workflow CI.
- `sample_count_summary.tsv`, maintained parameter schema, release automation, and repository community files.

### Changed

- Standard Illumina lane files now share the biological sample prefix before `_S<number>_L<lane>`.
- Reference caches are stored in fingerprinted subdirectories and are never automatically deleted.
- `gene_count_summary.tsv` is a deprecated compatibility copy of `sample_count_summary.tsv`; it will be removed before 1.0.0.
- Input validation is stricter and rejects ambiguous names, unsafe identifiers, repeated FASTQs, basename collisions, and shell-sensitive paths.

### Compatibility

- Scientific defaults remain Salmon 2.3.4, automatic library detection, `--deterministic`, `--seqBias`, `--gcBias`, and `countsFromAbundance = "no"`.
- Use `--lanes-as-samples` only to preserve the pre-0.3 generator behavior for detected lanes.

[Unreleased]: https://github.com/Thokas99/simple-nextflow-salmon/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/Thokas99/simple-nextflow-salmon/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/Thokas99/simple-nextflow-salmon/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Thokas99/simple-nextflow-salmon/compare/v0.2.1...v0.3.0
