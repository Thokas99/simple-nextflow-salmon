# Reference preparation and caching

SnS combines transcript and genome FASTAs, uses genome sequence names as decoys, checks duplicate/missing identifiers, and runs `salmon index --gencode`.

The cache key hashes GENCODE release, GRCh38 patch, Salmon version, k-mer, index options, and SHA-256 of transcript FASTA, genome FASTA, and GTF. Tasks build in isolated Nextflow work directories. A final task copies a complete set to a temporary sibling and atomically renames it to the fingerprint path. Existing destinations cause a safe failure; no recursive cache deletion occurs.

Reuse requires a valid JSON manifest, `info.json`, and all required Salmon index files. Malformed or incompatible entries are ignored and a distinct fingerprint is built. For an explicit rebuild, combine `--refresh_reference true` with an empty `--reference_cache_dir`; SnS refuses to overwrite an existing matching entry.
