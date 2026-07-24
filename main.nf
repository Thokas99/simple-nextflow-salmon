nextflow.enable.dsl = 2

include { FASTQC } from './modules/fastqc'
include { MULTIQC } from './modules/multiqc'
include { BUILD_FULL_DECOY_REFERENCE } from './modules/build_full_decoy_reference'
include { SALMON_INDEX } from './modules/salmon_index'
include { SALMON_QUANT } from './modules/salmon_quant'
include { SALMON_METRICS } from './modules/salmon_metrics'
include { TXIMPORT } from './modules/tximport'
include { ESTIMATED_COUNT_SUMMARY } from './modules/estimated_count_summary'

def as_bool(value, name) {
    if (value instanceof Boolean) return value
    if (value.toString().toLowerCase() in ['true', '1', 'yes']) return true
    if (value.toString().toLowerCase() in ['false', '0', 'no']) return false
    error "--${name} must be true or false"
}

def user_file(value, check = false) {
    def path = new File(value.toString())
    def resolved = path.isAbsolute() ? path : new File(launchDir.toString(), value.toString())
    file(resolved.toString(), checkIfExists: check)
}

def read_samplesheet(path) {
    def errors = []
    if (!path.isFile()) errors << "Samplesheet does not exist or is not a file: ${path}"
    else if (!path.toFile().canRead()) errors << "Samplesheet is not readable: ${path}"
    if (errors) error "Samplesheet validation failed:\n- ${errors.join('\n- ')}"

    def entries = path.readLines().withIndex().findAll { line, index -> line.trim() }.collect { line, index ->
        [row: index + 1, text: line]
    }
    if (!entries) error "Samplesheet validation failed:\n- Samplesheet is empty: ${path}"

    def header = entries[0].text.split(',', -1)*.trim()
    def required = ['sample', 'fastq_1', 'fastq_2']
    def missing = required - header
    def extra = header - required
    if (missing) errors << "Header row ${entries[0].row}: missing column(s): ${missing.join(', ')}"
    if (extra) errors << "Header row ${entries[0].row}: unexpected column(s): ${extra.join(', ')}"
    if (header.size() != required.size()) errors << "Header row ${entries[0].row}: expected exactly sample,fastq_1,fastq_2"
    if (errors) error "Samplesheet validation failed:\n- ${errors.unique().join('\n- ')}"

    def rows = []
    def row_keys = [] as Set
    def fastq_samples = [:]
    def fastq_names = [:]
    entries.drop(1).each { entry ->
        def fields = entry.text.split(',', -1)*.trim()
        if (fields.size() != header.size()) {
            errors << "Row ${entry.row}: expected ${header.size()} fields, found ${fields.size()}"
            return
        }

        def values = [header, fields].transpose().collectEntries()
        def sample = values.sample
        def r1_text = values.fastq_1
        def r2_text = values.fastq_2
        if (!sample) errors << "Row ${entry.row}, sample: value is empty"
        else if (!(sample ==~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/)) errors << "Row ${entry.row}, sample: unsafe output name '${sample}'"
        if (!r1_text) errors << "Row ${entry.row}, fastq_1: path is empty"
        if (!r2_text) errors << "Row ${entry.row}, fastq_2: path is empty; paired-end rows require both mates"
        if (!sample || !r1_text || !r2_text) return

        def r1 = user_file(r1_text)
        def r2 = user_file(r2_text)
        [[field: 'fastq_1', path: r1], [field: 'fastq_2', path: r2]].each { item ->
            if (!(item.path.name ==~ /(?i).+\.(fastq|fq)(\.gz)?$/)) errors << "Row ${entry.row}, ${item.field}: unsupported FASTQ extension '${item.path.name}'"
            if (!item.path.isFile()) errors << "Row ${entry.row}, ${item.field}: file not found '${item.path}'"
            else if (!item.path.toFile().canRead()) errors << "Row ${entry.row}, ${item.field}: file is not readable '${item.path}'"
        }
        if (r1 == r2) errors << "Row ${entry.row}: fastq_1 and fastq_2 point to the same file '${r1}'"

        def row_key = [sample, r1.toString(), r2.toString()]
        if (!row_keys.add(row_key)) errors << "Row ${entry.row}: duplicate samplesheet row for sample '${sample}'"
        [r1, r2].each { fastq ->
            def owner = fastq_samples[fastq.toString()]
            if (owner && owner != sample) errors << "Row ${entry.row}: FASTQ '${fastq}' is already assigned to biological sample '${owner}'"
            else if (owner == sample) errors << "Row ${entry.row}: FASTQ '${fastq}' is repeated within sample '${sample}'"
            else fastq_samples[fastq.toString()] = sample
            def named_path = fastq_names[fastq.name]
            if (named_path && named_path != fastq.toString()) errors << "Row ${entry.row}: FASTQ basename '${fastq.name}' is already used by '${named_path}'"
            else fastq_names[fastq.name] = fastq.toString()
        }
        rows << tuple(sample, r1, r2)
    }
    if (!entries.drop(1)) errors << 'Samplesheet has no data rows'
    if (errors) error "Samplesheet validation failed:\n- ${errors.unique().join('\n- ')}"

    def grouped = new LinkedHashMap()
    rows.each { sample, r1, r2 -> grouped.computeIfAbsent(sample) { [] } << tuple(r1, r2) }
    def samples = grouped.collect { sample, lanes ->
        tuple(sample, lanes.collect { it[0] }, lanes.collect { it[1] }, lanes.size())
    }
    [rows: rows, samples: samples]
}

def reference_inputs(raw_dir) {
    def release = params.gencode_release
    def patch = params.genome_patch
    [
        user_file("${raw_dir}/gencode.v${release}.transcripts.fa.gz", true),
        user_file("${raw_dir}/GRCh38.p${patch}.genome.fa.gz", true),
        user_file("${raw_dir}/gencode.v${release}.chr_patch_hapl_scaff.annotation.gtf.gz", true)
    ]
}

def derived_paths(raw_dir, cache_dir) {
    def raw = user_file(raw_dir, true)
    def dir = cache_dir ? user_file(cache_dir) : raw.parent.resolve('derived')
    [dir, dir.resolve('gentrome.fa'), dir.resolve('decoys.txt'),
     dir.resolve('annotation.gtf.gz'), dir.resolve('salmon_index'),
     dir.resolve('reference_manifest.tsv')]
}

def clean_derived(paths) {
    paths.drop(1).each { path ->
        if (path.isDirectory()) path.deleteDir()
        else if (path.exists()) path.delete()
    }
}

def manifest_matches(paths, refs) {
    def files = [paths[1], paths[2], paths[3], paths[5]]
    def index_files = ['index.ctab', 'index.ectab', 'index.refinfo', 'index.ssi',
                       'refseq.bin', 'refseq_offsets.json', 'info.json']
    try {
        if (!files.every { it.isFile() && it.toFile().canRead() && it.toFile().length() > 0 } || !paths[4].isDirectory() ||
            !index_files.every { name -> paths[4].resolve(name).isFile() && paths[4].resolve(name).toFile().canRead() && paths[4].resolve(name).toFile().length() > 0 }) return false

        def info = new groovy.json.JsonSlurper().parse(paths[4].resolve('info.json').toFile())
        if (!(info instanceof Map) || !(info.salmon_version instanceof String) || !(info.k instanceof Number) ||
            !(info.has_ec_table instanceof Boolean) || !(info.num_refs instanceof Number) || !(info.num_decoys instanceof Number) ||
            info.salmon_version != params.salmon_version || info.k != params.salmon_k ||
            !info.has_ec_table || info.num_refs <= 0 || info.num_decoys <= 0) return false

        def lines = paths[5].readLines()
        if (!lines || lines[0] != 'field\tvalue') return false
        def entries = lines.drop(1).collect { it.split('\t', -1) }
        if (!entries.every { it.size() == 2 && it[0] && it[1] } || entries.collect { it[0] }.toSet().size() != entries.size()) return false
        def manifest = entries.collectEntries { [(it[0]): it[1]] }
        def expected = [
            gencode_release: params.gencode_release.toString(),
            genome_patch: params.genome_patch.toString(),
            transcript_fasta: refs[0].name,
            genome_fasta: refs[1].name,
            gtf: refs[2].name,
            salmon_version: params.salmon_version.toString(),
            salmon_k: params.salmon_k.toString(),
            index_options: '--gencode'
        ]
        expected.every { key, value -> manifest[key] == value }
    } catch (Exception ignored) {
        false
    }
}

workflow {
    params.validate_only = as_bool(params.validate_only, 'validate_only')
    if (!params.samplesheet) error 'Provide --samplesheet /absolute/path/to/samplesheet.csv'

    user_file("${params.outdir}/pipeline_info").toFile().mkdirs()
    def samplesheet = user_file(params.samplesheet)
    def sample_data = read_samplesheet(samplesheet)
    def rows = sample_data.rows
    def samples = sample_data.samples
    def refs = reference_inputs(params.reference_dir)
    def derived = derived_paths(params.reference_dir, params.reference_cache_dir)

    def reuse = manifest_matches(derived, refs)
    def replicate_samples = samples.count { sample, r1s, r2s, lane_count -> lane_count > 1 }

    log.info "Samplesheet validation passed"
    log.info "Rows: ${rows.size()}"
    log.info "Biological samples: ${samples.size()}"
    log.info "Paired-end FASTQ pairs: ${rows.size()}"
    log.info "Technical replicate samples: ${replicate_samples}"

    if (!reuse && derived.drop(1).any { it.exists() }) {
        log.warn "The derived reference in ${derived[0]} is incompatible and will be rebuilt"
    }

    if (params.validate_only) {
        log.info reuse ? 'The existing Salmon index is compatible.' : 'The reference and index will be built.'
        return
    }

    if (!reuse && derived.drop(1).any { it.exists() }) {
        clean_derived(derived)
    }

    FASTQC(Channel.fromList(rows))

    if (reuse) {
        log.info "Reusing reference and Salmon index in ${derived[0]}"
        reference_gtf = Channel.value(file(derived[3]))
        salmon_index = Channel.value(tuple(file(derived[4]), file(derived[5])))
    } else {
        derived[0].toFile().mkdirs()
        BUILD_FULL_DECOY_REFERENCE(Channel.value(tuple(refs[0], refs[1], refs[2], derived[0])))
        SALMON_INDEX(BUILD_FULL_DECOY_REFERENCE.out.reference_files)
        reference_gtf = SALMON_INDEX.out.reference_gtf
        salmon_index = SALMON_INDEX.out.index
    }

    SALMON_QUANT(Channel.fromList(samples), salmon_index)
    quant_dirs = SALMON_QUANT.out.quant_dirs.map { sample, lane_count, dir -> dir }
    all_quant_dirs = quant_dirs.collect()
    TXIMPORT(all_quant_dirs, reference_gtf, samplesheet)
    ESTIMATED_COUNT_SUMMARY(all_quant_dirs, TXIMPORT.out.gene_counts, samplesheet)
    SALMON_METRICS(all_quant_dirs, samplesheet)

    reports = FASTQC.out.reports.mix(SALMON_QUANT.out.quant_dirs.map { sample, lane_count, dir -> dir })
    MULTIQC(reports.collect())
}
