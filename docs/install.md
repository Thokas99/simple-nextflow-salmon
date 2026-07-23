# Install

Install Java 17+, Nextflow `>=24.10.0`, and Conda, Mamba, or Micromamba. Clone the repository or run a tagged release directly from GitHub.

```bash
git clone https://github.com/Thokas99/simple-nextflow-salmon.git
cd simple-nextflow-salmon
nextflow config -profile conda
```

Nextflow creates the pinned environment from `envs/salmon-rnaseq.yml`; do not activate it manually.

For GitHub execution use `-r <RELEASE_TAG>` only after a release is tagged, with absolute paths for the samplesheet, reference, and results.
