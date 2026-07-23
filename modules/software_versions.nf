process SOFTWARE_VERSIONS {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy', overwrite: true

    cpus { params.versions_cpus }
    memory { params.versions_memory }

    input:
    path samplesheet
    path reference_manifest
    val nextflow_version

    output:
    path "software_versions.yml", emit: versions
    path "run_provenance.json", emit: provenance

    script:
    """
    mkdir -p versions_tmp
    {
      echo "simple-nextflow-salmon:"
      echo "  pipeline_version: '${params.pipeline_version}'"
      echo "  nextflow: '${nextflow_version}'"
      echo "  salmon: '\$(salmon --version 2>/dev/null | awk '{print \$NF}' || true)'"
      echo "  fastqc: '\$(fastqc --version 2>/dev/null | awk '{print \$2}' || true)'"
      echo "  multiqc: '\$(multiqc --version 2>/dev/null | awk '{print \$3}' || true)'"
      echo "  R: '\$(R --version 2>/dev/null | head -1 | awk '{print \$3}' || true)'"
      echo "  tximport: '\$(Rscript -e 'cat(as.character(packageVersion(\"tximport\")))' 2>/dev/null || true)'"
      echo "  seqkit: '\$(seqkit version 2>/dev/null | awk '{print \$2}' || true)'"
    } > software_versions.yml

    python3 ${projectDir}/scripts/write_run_provenance.py \\
      --out run_provenance.json \\
      --pipeline_version ${params.pipeline_version} \\
      --samplesheet ${samplesheet} \\
      --reference_manifest ${reference_manifest} \\
      --software_versions software_versions.yml
    """

    stub:
    """
    cat > software_versions.yml <<'EOF'
simple-nextflow-salmon:
  pipeline_version: '${params.pipeline_version}'
  nextflow: '${nextflow_version}'
EOF
    python3 ${projectDir}/scripts/write_run_provenance.py \\
      --out run_provenance.json \\
      --pipeline_version ${params.pipeline_version} \\
      --samplesheet ${samplesheet} \\
      --reference_manifest ${reference_manifest} \\
      --software_versions software_versions.yml
    """
}
