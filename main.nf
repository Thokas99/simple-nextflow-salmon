nextflow.enable.dsl = 2

include { FASTQC } from './modules/fastqc'
include { MULTIQC } from './modules/multiqc'
include { BUILD_FULL_DECOY_REFERENCE } from './modules/build_full_decoy_reference'
include { SALMON_INDEX } from './modules/salmon_index'
include { PUBLISH_REFERENCE_CACHE } from './modules/publish_reference_cache'
include { SALMON_QUANT } from './modules/salmon_quant'
include { SALMON_METRICS } from './modules/salmon_metrics'
include { TXIMPORT } from './modules/tximport'
include { ESTIMATED_COUNT_SUMMARY } from './modules/estimated_count_summary'
include { PROVENANCE } from './modules/provenance'

def fail_errors(errors, heading = 'Parameter validation failed') {
    if (errors) error "${heading}:\n- ${errors.unique().join('\n- ')}"
}

def as_bool(value, name, errors) {
    if (value instanceof Boolean) return value
    if (value?.toString()?.toLowerCase() in ['true', '1', 'yes']) return true
    if (value?.toString()?.toLowerCase() in ['false', '0', 'no']) return false
    errors << "--${name} must be true or false"
    false
}

def user_file(value, check = false) {
    def path = new File(value.toString())
    def resolved = path.isAbsolute() ? path : new File(launchDir.toString(), value.toString())
    file(resolved.toString(), checkIfExists: check)
}

def safe_user_path(value, name, errors, allow_existing = true) {
    if (!value?.toString()?.trim()) {
        errors << "--${name} must not be empty"
        return null
    }
    def text = value.toString()
    if (text =~ /[\n\r\u0000'"`\$;&|<>]/) errors << "--${name} contains shell-sensitive characters: ${text}"
    def path = user_file(text)
    if (path.exists() && !allow_existing) errors << "--${name} already exists: ${path}"
    path
}

def sha256(path) {
    def digest = java.security.MessageDigest.getInstance('SHA-256')
    path.toFile().withInputStream { stream ->
        new java.security.DigestInputStream(stream, digest).transferTo(java.io.OutputStream.nullOutputStream())
    }
    digest.digest().encodeHex().toString()
}

def validate_params() {
    def errors = []
    def boolean_names = ['validate_only', 'refresh_reference']
    def booleans = boolean_names.collectEntries { name -> [(name): as_bool(params[name], name, errors)] }
    if (!(params.lib_type ==~ /^(A|[IU][SFUO][RFUO])$/)) errors << "--lib_type '${params.lib_type}' is invalid; use A or a Salmon paired-end library code"
    def salmon_k = params.salmon_k.toString().isInteger() ? params.salmon_k.toString().toInteger() : 0
    if (salmon_k < 1 || salmon_k > 31 || salmon_k % 2 == 0) errors << '--salmon_k must be an odd integer from 1 to 31'
    if (!params.gencode_release.toString().isInteger() || params.gencode_release.toString().toInteger() < 1) errors << '--gencode_release must be a positive integer'
    if (!params.genome_patch.toString().isInteger() || params.genome_patch.toString().toInteger() < 1) errors << '--genome_patch must be a positive integer'
    ['fastqc', 'reference', 'index', 'salmon', 'tximport', 'summary', 'multiqc'].each { process ->
        def cpus = params["${process}_cpus"]
        if (!cpus.toString().isInteger() || cpus.toString().toInteger() < 1) errors << "--${process}_cpus must be a positive integer"
        def memory = params["${process}_memory"]?.toString()
        if (!(memory ==~ /(?i)^\d+(\.\d+)?\s*(KB|MB|GB|TB)$/)) errors << "--${process}_memory must include a positive unit, for example '4 GB'"
    }
    def outdir = safe_user_path(params.outdir, 'outdir', errors)
    def reference_dir = safe_user_path(params.reference_dir, 'reference_dir', errors)
    def cache_root = safe_user_path(params.reference_cache_dir ?: new File(reference_dir?.toFile()?.parent ?: launchDir.toFile(), 'derived').toString(), 'reference_cache_dir', errors)
    if (outdir && cache_root && outdir.toString() == cache_root.toString()) errors << '--outdir and --reference_cache_dir must be different'
    fail_errors(errors)
    [booleans: booleans, outdir: outdir, reference_dir: reference_dir, cache_root: cache_root]
}

def reference_inputs(raw_dir) {
    def refs = [
        user_file("${raw_dir}/gencode.v${params.gencode_release}.transcripts.fa.gz"),
        user_file("${raw_dir}/GRCh38.p${params.genome_patch}.genome.fa.gz"),
        user_file("${raw_dir}/gencode.v${params.gencode_release}.chr_patch_hapl_scaff.annotation.gtf.gz")
    ]
    def errors = []
    refs.each { ref ->
        if (!ref.isFile()) errors << "Reference file not found: ${ref}"
        else if (!ref.toFile().canRead() || ref.toFile().length() == 0) errors << "Reference file is unreadable or empty: ${ref}"
    }
    fail_errors(errors, 'Reference validation failed')
    refs
}

def read_samplesheet(path) {
    def command = ['python3', "${projectDir}/scripts/validate_samplesheet.py", path.toString(), '--launch-dir', launchDir.toString()]
    def process = new ProcessBuilder(command).redirectErrorStream(true).start()
    def output = process.inputStream.getText('UTF-8')
    if (process.waitFor() != 0) error output.trim()
    new groovy.json.JsonSlurper().parseText(output)
}

def cache_manifest(cache_dir, expected) {
    def required_index = ['index.ctab', 'index.ectab', 'index.refinfo', 'index.ssi', 'refseq.bin', 'refseq_offsets.json', 'info.json']
    try {
        def manifest_file = cache_dir.resolve('reference_manifest.json')
        def index = cache_dir.resolve('salmon_index')
        if (!manifest_file.isFile() || !cache_dir.resolve('gentrome.fa').isFile() || !cache_dir.resolve('decoys.txt').isFile() ||
            !cache_dir.resolve('annotation.gtf.gz').isFile() || !index.isDirectory() ||
            !required_index.every { name -> index.resolve(name).isFile() && index.resolve(name).toFile().length() > 0 }) return null
        def manifest = new groovy.json.JsonSlurper().parse(manifest_file.toFile())
        def info = new groovy.json.JsonSlurper().parse(index.resolve('info.json').toFile())
        if (!(manifest instanceof Map) || !expected.every { key, value -> manifest[key]?.toString() == value.toString() }) return null
        if (!(info instanceof Map) || info.salmon_version.toString() != params.salmon_version.toString() || info.k.toString() != params.salmon_k.toString() ||
            info.has_ec_table != true || !(info.num_refs instanceof Number) || info.num_refs <= 0 ||
            !(info.num_decoys instanceof Number) || info.num_decoys <= 0) return null
        manifest
    } catch (Exception _ignored) {
        null
    }
}

workflow {
    def checked = validate_params()
    if (!params.samplesheet) error 'Provide --samplesheet /path/to/samplesheet.csv'
    def samplesheet = user_file(params.samplesheet)
    def sample_data = read_samplesheet(samplesheet)
    def rows = sample_data.rows.collect { row -> tuple(row.sample, file(row.fastq_1), file(row.fastq_2)) }
    def samples = sample_data.samples.collect { sample -> tuple(sample.sample, sample.fastq_1.collect { path -> file(path) }, sample.fastq_2.collect { path -> file(path) }, sample.fastq_pairs) }
    def refs = reference_inputs(checked.reference_dir)
    def fingerprints = [transcript_sha256: sha256(refs[0]), genome_sha256: sha256(refs[1]), gtf_sha256: sha256(refs[2])]
    def identity = [pipeline_version: workflow.manifest.version, gencode_release: params.gencode_release,
                    genome_patch: params.genome_patch, salmon_version: params.salmon_version,
                    seqkit_version: '2.10.0', salmon_k: params.salmon_k, index_options: '--gencode'] + fingerprints
    def cache_key = java.security.MessageDigest.getInstance('SHA-256').digest(groovy.json.JsonOutput.toJson(identity).bytes).encodeHex().toString()
    def cache_dir = checked.cache_root.resolve(cache_key)
    if (checked.booleans.refresh_reference && cache_dir.exists()) {
        error "--refresh_reference will not overwrite immutable cache ${cache_dir}; select an empty --reference_cache_dir"
    }
    def reuse_manifest = checked.booleans.refresh_reference ? null : cache_manifest(cache_dir, identity)

    checked.outdir.resolve('pipeline_info').toFile().mkdirs()
    def provenance = [started_at: java.time.Instant.now().toString(), state: 'completed', pipeline_name: workflow.manifest.name, pipeline_version: workflow.manifest.version,
        git_revision: workflow.revision ?: 'local', nextflow_version: workflow.nextflow.version,
        launch_command: "nextflow run ${workflow.projectDir.name} -profile ${workflow.profile ?: 'standard'}",
        profile: workflow.profile ?: 'standard', parameters: params.findAll { key, _value -> !(key.toString() =~ /(?i)(token|secret|password|key)/) }
            .collectEntries { key, value -> [(key): key.toString().endsWith('dir') || key == 'samplesheet' ? new File(value?.toString() ?: '').name : value] },
        references: [[filename: refs[0].name, sha256: fingerprints.transcript_sha256], [filename: refs[1].name, sha256: fingerprints.genome_sha256], [filename: refs[2].name, sha256: fingerprints.gtf_sha256]],
        reference_cache_key: cache_key, biological_samples: sample_data.biological_samples,
        fastq_pairs: sample_data.fastq_pairs, technical_replicate_samples: sample_data.technical_replicate_samples,
        salmon_version: params.salmon_version]

    log.info "Samplesheet validation passed: ${sample_data.biological_samples} biological samples, ${sample_data.fastq_pairs} FASTQ pairs, ${sample_data.technical_replicate_samples} technical-replicate samples"
    if (checked.booleans.validate_only) {
        log.info reuse_manifest ? "Compatible immutable cache: ${cache_key}" : "Reference cache will be built: ${cache_key}"
        return
    }

    FASTQC(channel.fromList(rows))
    if (reuse_manifest) {
        log.info "Reusing immutable reference cache ${cache_key}"
        reference_gtf = channel.value(file(cache_dir.resolve('annotation.gtf.gz')))
        salmon_index = channel.value(tuple(file(cache_dir.resolve('salmon_index')), file(cache_dir.resolve('reference_manifest.json'))))
    } else {
        BUILD_FULL_DECOY_REFERENCE(channel.value(tuple(refs[0], refs[1], refs[2])))
        SALMON_INDEX(BUILD_FULL_DECOY_REFERENCE.out.reference_files, channel.value(identity))
        reference_gtf = SALMON_INDEX.out.reference_gtf
        salmon_index = SALMON_INDEX.out.index
        PUBLISH_REFERENCE_CACHE(BUILD_FULL_DECOY_REFERENCE.out.reference_files, SALMON_INDEX.out.index,
            channel.value(tuple(cache_dir.toString(), cache_key)))
    }

    SALMON_QUANT(channel.fromList(samples), salmon_index)
    quant_dirs = SALMON_QUANT.out.quant_dirs.map { _sample, _pair_count, dir -> dir }
    all_quant_dirs = quant_dirs.collect()
    TXIMPORT(all_quant_dirs, reference_gtf, samplesheet)
    ESTIMATED_COUNT_SUMMARY(all_quant_dirs, TXIMPORT.out.gene_estimated_counts, samplesheet)
    SALMON_METRICS(all_quant_dirs, samplesheet)
    reports = FASTQC.out.reports.mix(SALMON_QUANT.out.quant_dirs.map { _sample, _pair_count, dir -> dir })
    MULTIQC(reports.collect())
    PROVENANCE(channel.value(provenance), MULTIQC.out.report, ESTIMATED_COUNT_SUMMARY.out.sample_count_summary, SALMON_METRICS.out.metrics)
}
