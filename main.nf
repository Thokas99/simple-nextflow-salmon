nextflow.enable.dsl = 2

include { FASTQC } from './modules/fastqc'
include { MULTIQC } from './modules/multiqc'
include { BUILD_FULL_DECOY_REFERENCE } from './modules/build_full_decoy_reference'
include { SALMON_INDEX } from './modules/salmon_index'
include { SALMON_QUANT } from './modules/salmon_quant'
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
    def lines = path.readLines().findAll { it.trim() }
    if (!lines) error "Samplesheet is empty: ${path}"
    def header = lines[0].split(',', -1)*.trim()
    if (header != ['sample', 'fastq_1', 'fastq_2']) {
        error 'Samplesheet columns must be exactly: sample,fastq_1,fastq_2'
    }

    def samples = [] as Set
    def fastqs = [] as Set
    def rows = lines.drop(1).withIndex().collect { line, index ->
        def fields = line.split(',', -1)*.trim()
        if (fields.size() != 3) error "Malformed samplesheet row ${index + 2}: expected 3 fields"
        def (sample, r1_text, r2_text) = fields
        if (!(sample ==~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/)) error "Unsafe sample ID on row ${index + 2}: ${sample}"
        if (!r1_text || !r2_text) error "Sample ${sample} must have both fastq_1 and fastq_2"
        if (!samples.add(sample)) error "Duplicate sample ID: ${sample}"
        def r1 = user_file(r1_text, true)
        def r2 = user_file(r2_text, true)
        if (!r1.toFile().isFile() || !r2.toFile().isFile()) error "FASTQ path is not a file near sample: ${sample}"
        if (r1 == r2) error "Sample ${sample} uses the same file for R1 and R2"
        if (!fastqs.add(r1) || !fastqs.add(r2)) error "FASTQ assigned more than once near sample: ${sample}"
        tuple(sample, r1, r2)
    }
    if (!rows) error "Samplesheet has no sample rows: ${path}"
    rows
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

def derived_paths(raw_dir) {
    def raw = user_file(raw_dir, true)
    def dir = raw.parent.resolve('derived')
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
    if (!files.every { it.isFile() && it.toFile().length() > 0 } || !paths[4].isDirectory() ||
        !index_files.every { name -> paths[4].resolve(name).isFile() && paths[4].resolve(name).toFile().length() > 0 }) return false

    def info = new groovy.json.JsonSlurper().parse(paths[4].resolve('info.json').toFile())
    if (info.salmon_version != params.salmon_version || info.k != params.salmon_k ||
        !info.has_ec_table || info.num_refs <= 0 || info.num_decoys <= 0) return false
    def manifest = paths[5].readLines().drop(1).collectEntries { line ->
        def fields = line.split('\t', 2)
        fields.size() == 2 ? [(fields[0]): fields[1]] : [:]
    }
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
}

workflow {
    params.validate_only = as_bool(params.validate_only, 'validate_only')
    if (!params.samplesheet) error 'Provide --samplesheet /absolute/path/to/samplesheet.csv'

    def samplesheet = user_file(params.samplesheet, true)
    def rows = read_samplesheet(samplesheet)
    def refs = reference_inputs(params.reference_dir)
    def derived = derived_paths(params.reference_dir)

    def reuse = manifest_matches(derived, refs)

    if (params.validate_only) {
        log.info "Validated ${rows.size()} sample(s) and the requested reference inputs."
        log.info reuse ? 'The existing Salmon index is compatible.' : 'The reference and index will be built.'
        return
    }

    if (!reuse && derived.drop(1).any { it.exists() }) {
        log.warn "Removing incomplete or incompatible derived reference in ${derived[0]}"
        clean_derived(derived)
    }

    FASTQC(Channel.fromList(rows))

    if (reuse) {
        log.info "Reusing reference and Salmon index in ${derived[0]}"
        reference_gtf = Channel.value(file(derived[3]))
        salmon_index = Channel.value(tuple(file(derived[4]), file(derived[5])))
    } else {
        BUILD_FULL_DECOY_REFERENCE(Channel.value(tuple(refs[0], refs[1], refs[2])))
        SALMON_INDEX(BUILD_FULL_DECOY_REFERENCE.out.reference_files)
        reference_gtf = SALMON_INDEX.out.reference_gtf
        salmon_index = SALMON_INDEX.out.index
    }

    SALMON_QUANT(Channel.fromList(rows), salmon_index)
    quant_dirs = SALMON_QUANT.out.quant_dirs.map { sample, dir -> dir }
    TXIMPORT(quant_dirs.collect(), reference_gtf, samplesheet)
    ESTIMATED_COUNT_SUMMARY(quant_dirs.collect(), TXIMPORT.out.gene_counts, samplesheet)

    reports = FASTQC.out.reports.mix(SALMON_QUANT.out.quant_dirs.map { sample, dir -> dir })
    MULTIQC(reports.collect())
}
