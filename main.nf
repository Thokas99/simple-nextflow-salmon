nextflow.enable.dsl = 2

include { FASTQC } from './modules/fastqc'
include { MULTIQC } from './modules/multiqc'
include { BUILD_FULL_DECOY_REFERENCE } from './modules/build_full_decoy_reference'
include { SALMON_INDEX } from './modules/salmon_index'
include { SALMON_QUANT } from './modules/salmon_quant'
include { TXIMPORT } from './modules/tximport'
include { ESTIMATED_COUNT_SUMMARY } from './modules/estimated_count_summary'
include { SOFTWARE_VERSIONS } from './modules/software_versions'

def help_text() {
    """
simple-nextflow-salmon ${params.pipeline_version}

Required input:
  --samplesheet FILE              CSV/TSV with sample,fastq_1,fastq_2
  --fastq_dir DIR                 Optional: generate a samplesheet from paired FASTQs

Common parameters:
  --outdir DIR                    Output directory [${params.outdir}]
  --reference_dir DIR             Raw GENCODE reference directory [${params.reference_dir}]
  --gencode_release INT           Pinned GENCODE release [${params.gencode_release}]
  --genome_patch INT              Pinned GRCh38 patch [${params.genome_patch}]
  --lib_type STR                  Salmon library type [${params.lib_type}]
  --salmon_k INT                  Salmon index k-mer size [${params.salmon_k}]
  --validate_only true            Validate inputs and stop before processes
  --rebuild_reference true        Force a clean rebuild of derived reference artifacts

Examples:
  nextflow run . --fastq_dir fastqs --samplesheet samplesheet.csv --validate_only true -profile conda
  nextflow run . --samplesheet samplesheet.csv --outdir results -profile conda
"""
}

def as_bool(value, name) {
    if (value instanceof Boolean) return value
    def text = value.toString().toLowerCase()
    if (text in ['true', '1', 'yes']) return true
    if (text in ['false', '0', 'no']) return false
    error "Parameter --${name} must be true or false, got: ${value}"
}

def positive_int(value, name) {
    if (!(value.toString() ==~ /^\d+$/) || value.toInteger() < 1) {
        error "Parameter --${name} must be a positive integer, got: ${value}"
    }
    value.toInteger()
}

def validate_memory(value, name) {
    if (!(value.toString() ==~ /(?i)^\d+(\.\d+)?\s*(B|KB|MB|GB|TB)$/)) {
        error "Parameter --${name} must be a Nextflow memory string such as '4 GB', got: ${value}"
    }
}

def validate_common_params() {
    params.validate_only = as_bool(params.validate_only, 'validate_only')
    params.rebuild_reference = as_bool(params.rebuild_reference, 'rebuild_reference')

    params.gencode_release = positive_int(params.gencode_release, 'gencode_release')
    params.genome_patch = positive_int(params.genome_patch, 'genome_patch')

    params.salmon_k = positive_int(params.salmon_k, 'salmon_k')
    if (params.salmon_k < 19 || params.salmon_k > 31 || params.salmon_k % 2 == 0) {
        error "Parameter --salmon_k must be an odd integer between 19 and 31, got: ${params.salmon_k}"
    }

    if (!params.lib_type?.toString()?.trim()) error "Parameter --lib_type cannot be empty"
    if (!(params.lib_type.toString() ==~ /^[A-Za-z]+$/)) error "Parameter --lib_type has invalid Salmon library-type syntax: ${params.lib_type}"

    ['fastqc', 'reference', 'index', 'salmon', 'tximport', 'summary', 'multiqc', 'versions'].each { key ->
        params["${key}_cpus"] = positive_int(params["${key}_cpus"], "${key}_cpus")
        validate_memory(params["${key}_memory"], "${key}_memory")
    }

    if (!params.samplesheet && !params.fastq_dir) error "Provide --samplesheet or --fastq_dir"
    if (!params.outdir?.toString()?.trim()) error "Parameter --outdir cannot be empty"
    new File(params.outdir.toString()).mkdirs()
    if (!new File(params.outdir.toString()).isDirectory()) error "Output directory is not usable: ${params.outdir}"
}

def run_json_command(List command) {
    def proc = command.execute(null, new File(projectDir.toString()))
    def stdout = new StringBuffer()
    def stderr = new StringBuffer()
    proc.consumeProcessOutput(stdout, stderr)
    def code = proc.waitFor()
    if (code != 0) error stderr.toString().trim()
    new groovy.json.JsonSlurper().parseText(stdout.toString())
}

def resolve_launch_path(path) {
    if (!path) return null
    def p = file(path.toString())
    p.isAbsolute() ? p : file("${launchDir}/${path}")
}

def resolve_input_path(path) {
    def p = resolve_launch_path(path)
    if (p?.exists()) return p
    def project_path = file("${projectDir}/${path}")
    project_path.exists() ? project_path : p
}

def make_samplesheet(fastq_dir, out_path) {
    def command = ['python3', "${projectDir}/scripts/make_samplesheet.py", fastq_dir.toString(), '-o', out_path.toString(), '--json']
    def result = run_json_command(command)
    log.info "Wrote ${result.samples} sample(s) to ${result.samplesheet}"
    result.samplesheet.toString()
}

def parse_samplesheet(path) {
    def command = ['python3', "${projectDir}/scripts/validate_samplesheet.py", path.toString(), '--json']
    def result = run_json_command(command)
    result.rows.collect { row -> tuple(row.sample.toString(), file(row.fastq_1.toString(), checkIfExists: true), file(row.fastq_2.toString(), checkIfExists: true)) }
}

def sha256_file(path) {
    def proc = ['sha256sum', path.toString()].execute()
    def stdout = new StringBuffer()
    def stderr = new StringBuffer()
    proc.consumeProcessOutput(stdout, stderr)
    def code = proc.waitFor()
    if (code != 0) error "Could not calculate SHA256 for ${path}: ${stderr.toString().trim()}"
    stdout.toString().trim().split(/\s+/)[0]
}

def exactly_one(files, label) {
    if (files.size() == 0) error "Missing ${label} in ${params.reference_dir}"
    if (files.size() > 1) error "Ambiguous ${label} in ${params.reference_dir}: ${files*.name.join(', ')}"
    files[0]
}

def validate_reference_dir(path) {
    def ref_dir = file(path, type: 'dir', checkIfExists: true)
    def files = ref_dir.listFiles().findAll { it.isFile() }
    def release = params.gencode_release.toString()
    def patch = params.genome_patch.toString()

    def tx_re = "gencode\\.v${release}\\.transcripts\\.fa\\.gz"
    def gtf_re = "gencode\\.v${release}\\..*annotation\\.gtf\\.gz"
    def genome_re = "GRCh38\\.p${patch}\\.genome\\.fa\\.gz"

    def tx = exactly_one(files.findAll { it.name ==~ tx_re }, "GENCODE v${release} transcript FASTA")
    def gtf = exactly_one(files.findAll { it.name ==~ gtf_re }, "GENCODE v${release} GTF")
    def genome = exactly_one(files.findAll { it.name ==~ genome_re }, "GRCh38.p${patch} genome FASTA")

    [tx, genome, gtf]
}

def derived_reference(path) {
    def raw_dir = file(path, type: 'dir', checkIfExists: true)
    def derived_dir = raw_dir.parent.resolve('derived')
    [
        derived_dir,
        file("${derived_dir}/gentrome.fa"),
        file("${derived_dir}/decoys.txt"),
        file("${derived_dir}/annotation.gtf.gz"),
        file("${derived_dir}/salmon_index"),
        file("${derived_dir}/reference_manifest.json")
    ]
}

def clean_derived_reference(d) {
    [d[1], d[2], d[3], d[5]].each { f -> if (f.exists()) f.delete() }
    if (d[4].exists()) d[4].deleteDir()
}

def reference_manifest_matches(refs, d) {
    if (![d[1], d[2], d[3], d[4], d[5]].every { it.exists() }) return false

    def manifest = new groovy.json.JsonSlurper().parse(d[5])
    def expected = [
        manifest_format_version: 1,
        gencode_release: params.gencode_release.toString(),
        grch38_patch: params.genome_patch.toString(),
        transcript_fasta_filename: refs[0].name,
        transcript_fasta_sha256: sha256_file(refs[0]),
        genome_fasta_filename: refs[1].name,
        genome_fasta_sha256: sha256_file(refs[1]),
        gtf_filename: refs[2].name,
        gtf_sha256: sha256_file(refs[2]),
        salmon_version: params.salmon_version.toString(),
        salmon_index_k: params.salmon_k.toString(),
        salmon_index_options: params.salmon_index_options.toString(),
        decoy_generation_method: 'genome_fasta_headers_only'
    ]

    expected.every { key, value -> manifest[key]?.toString() == value.toString() }
}

workflow {
    if (params.help) {
        log.info help_text()
        return
    }

    params.outdir = resolve_launch_path(params.outdir)
    if (params.samplesheet) params.samplesheet = resolve_input_path(params.samplesheet)
    if (params.fastq_dir) params.fastq_dir = resolve_input_path(params.fastq_dir)
    if (params.generated_samplesheet) params.generated_samplesheet = resolve_launch_path(params.generated_samplesheet)
    params.reference_dir = resolve_input_path(params.reference_dir)

    validate_common_params()

    def samplesheet = resolve_launch_path(params.samplesheet)
    if (params.fastq_dir) {
        samplesheet = resolve_launch_path(params.samplesheet ?: params.generated_samplesheet ?: "${params.outdir}/samplesheet.generated.csv")
        samplesheet = make_samplesheet(params.fastq_dir, samplesheet)
    }

    def rows = parse_samplesheet(samplesheet)
    def refs = validate_reference_dir(params.reference_dir)
    def derived = derived_reference(params.reference_dir)

    if (params.rebuild_reference) clean_derived_reference(derived)

    def reuse_reference = reference_manifest_matches(refs, derived)
    if (!reuse_reference && [derived[1], derived[2], derived[3], derived[4], derived[5]].any { it.exists() } && !params.rebuild_reference) {
        error "Existing derived reference is incompatible with requested inputs/settings. Rerun with --rebuild_reference true to rebuild intentionally."
    }

    if (params.validate_only) {
        log.info "Validated ${rows.size()} sample(s) from ${samplesheet}"
        log.info "Reference inputs found in ${params.reference_dir}"
        log.info reuse_reference ? "Existing derived reference/index is compatible." : "Derived reference/index will be built during the full run."
        log.info "Inspect the samplesheet, then rerun without --validate_only true to launch the pipeline."
        return
    }

    def samples_for_qc = Channel.fromList(rows)
    def samples_for_quant = Channel.fromList(rows)

    FASTQC(samples_for_qc)

    if (reuse_reference) {
        log.info "Reusing compatible derived reference/index in ${derived[0]}"
        reference_gtf = Channel.value(file(derived[3]))
        salmon_index = Channel.value(tuple(file(derived[4], type: 'dir'), file(derived[5])))
    } else {
        reference_inputs = Channel.value(tuple(file(refs[0]), file(refs[1]), file(refs[2])))
        BUILD_FULL_DECOY_REFERENCE(reference_inputs)
        SALMON_INDEX(BUILD_FULL_DECOY_REFERENCE.out.reference_files)
        reference_gtf = SALMON_INDEX.out.reference_gtf
        salmon_index = SALMON_INDEX.out.index
    }

    SALMON_QUANT(samples_for_quant, salmon_index)
    quant_dirs = SALMON_QUANT.out.quant_dirs.map { sample, quant_dir -> quant_dir }

    TXIMPORT(quant_dirs.collect(), reference_gtf, file(samplesheet, checkIfExists: true))
    ESTIMATED_COUNT_SUMMARY(quant_dirs.collect(), TXIMPORT.out.gene_counts, file(samplesheet, checkIfExists: true))

    multiqc_inputs = FASTQC.out.reports.mix(SALMON_QUANT.out.quant_dirs.map { sample, quant_dir -> quant_dir })
    MULTIQC(multiqc_inputs.collect())

    SOFTWARE_VERSIONS(file(samplesheet, checkIfExists: true), salmon_index.map { index_dir, manifest -> manifest }, workflow.nextflow.version)
}
