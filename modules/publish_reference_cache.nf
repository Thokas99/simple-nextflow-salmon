process PUBLISH_REFERENCE_CACHE {
    tag "$cache_key"
    cpus 1
    memory '1 GB'

    input:
    tuple path(gentrome), path(decoys), path(gtf)
    tuple path(index), path(manifest)
    tuple val(cache_dir), val(cache_key)

    output:
    val cache_key, emit: cache_key

    script:
    """
    target='${cache_dir}'
    parent=\$(dirname "\$target")
    mkdir -p "\$parent"
    tmp=\$(mktemp -d "\$parent/.${cache_key}.XXXXXX")
    trap 'rm -rf "\$tmp"' EXIT
    cp "${gentrome}" "\$tmp/gentrome.fa"
    cp "${decoys}" "\$tmp/decoys.txt"
    cp "${gtf}" "\$tmp/annotation.gtf.gz"
    cp -R "${index}" "\$tmp/salmon_index"
    cp "${manifest}" "\$tmp/reference_manifest.json"
    test -s "\$tmp/reference_manifest.json" -a -s "\$tmp/salmon_index/info.json"
    if ! mkdir "\$target" 2>/dev/null; then
      echo "Immutable cache already exists: \$target" >&2
      exit 1
    fi
    rmdir "\$target"
    mv "\$tmp" "\$target"
    trap - EXIT
    """
}
