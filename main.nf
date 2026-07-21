nextflow.enable.dsl = 2

include { FASTQC } from './modules/fastqc'
include { MULTIQC } from './modules/multiqc'
include { BUILD_FULL_DECOY_REFERENCE } from './modules/build_full_decoy_reference'
include { SALMON_INDEX } from './modules/salmon_index'
include { SALMON_QUANT } from './modules/salmon_quant'
include { TXIMPORT } from './modules/tximport'
include { RAW_COUNT_SUMMARY } from './modules/raw_count_summary'

params.samplesheet = null
params.outdir = 'results'
params.reference_dir = 'reference/GRCh38_GENCODE/raw'
params.lib_type = 'A'
params.salmon_k = 31
params.rebuild_reference = false

def split_row(line, sep) {
    (line.split(java.util.regex.Pattern.quote(sep), -1) as List).collect { it.trim() }
}

def parse_samplesheet(path) {
    def sheet = file(path, checkIfExists: true)
    def lines = sheet.text.readLines()
        .collect { it.replaceFirst(/\r$/, '') }
        .findAll { it.trim() && !it.trim().startsWith('#') }

    if (!lines) error "Samplesheet is empty: ${path}"

    def comma_header = split_row(lines[0], ',')
    def tab_header = split_row(lines[0], '\t')
    def comma_ok = ['sample', 'fastq_1', 'fastq_2'].every { comma_header.contains(it) }
    def tab_ok = ['sample', 'fastq_1', 'fastq_2'].every { tab_header.contains(it) }
    if (comma_ok && tab_ok) error "Samplesheet delimiter is ambiguous: ${path}"
    if (!comma_ok && !tab_ok) error "Samplesheet must be CSV or TSV with columns: sample, fastq_1, fastq_2"

    def sep = comma_ok ? ',' : '\t'
    def header = split_row(lines[0], sep)
    if (header.any { it == '' }) error "Samplesheet has empty header columns: ${path}"

    def col = [:]
    header.eachWithIndex { name, i -> col[name] = i }

    def seen_samples = [] as Set
    def seen_fastqs = [] as Set
    lines.drop(1).collect { line ->
        def row = split_row(line, sep)
        def sample = row[col.sample]
        def r1 = row[col.fastq_1]
        def r2 = row[col.fastq_2]

        if (!sample) error "Samplesheet row has empty sample ID: ${line}"
        if (seen_samples.contains(sample)) error "Duplicate sample ID '${sample}'. Keep sample IDs unique in this workflow."
        if (!r1 || !r2) error "Sample '${sample}' must have both fastq_1 and fastq_2"
        if (r1 == r2) error "Sample '${sample}' has identical fastq_1 and fastq_2"
        [r1, r2].each {
            if (seen_fastqs.contains(it)) error "FASTQ assigned more than once: ${it}"
            if (!file(it).exists()) error "FASTQ does not exist: ${it}"
            seen_fastqs << it
        }
        seen_samples << sample

        tuple(sample, file(r1), file(r2))
    }
}

def exactly_one(files, label) {
    if (files.size() == 0) error "Missing ${label} in ${params.reference_dir}\nDownload the matching GENCODE Human ALL files from https://www.gencodegenes.org/human/ into ${params.reference_dir}"
    if (files.size() > 1) error "Ambiguous ${label} in ${params.reference_dir}: ${files*.name.join(', ')}"
    files[0]
}

def validate_reference_dir(path) {
    def current_gencode_release = '50'
    def current_grch38_patch = '14'
    def ref_dir = file(path, type: 'dir', checkIfExists: true)
    def files = ref_dir.listFiles().findAll { it.isFile() }
    def names = files*.name

    def foreign = names.findAll { it ==~ /(?i).*(refseq|ucsc|ensembl).*/ }
    if (foreign) error "Reference directory appears to mix non-GENCODE sources: ${foreign.join(', ')}"

    def tx = exactly_one(files.findAll { it.name ==~ /gencode\.v\d+\.transcripts\.fa\.gz/ }, 'GENCODE comprehensive transcript FASTA ALL')
    def gtf = exactly_one(files.findAll { it.name ==~ /gencode\.v\d+\.chr_patch_hapl_scaff\.annotation\.gtf\.gz/ }, 'GENCODE comprehensive annotation GTF ALL')
    def genome = exactly_one(files.findAll { it.name ==~ /GRCh38\.p\d+\.genome\.fa\.gz/ }, 'GENCODE GRCh38 genome FASTA ALL')

    def tx_release = (tx.name =~ /gencode\.v(\d+)\./)[0][1]
    def gtf_release = (gtf.name =~ /gencode\.v(\d+)\./)[0][1]
    def genome_patch = (genome.name =~ /GRCh38\.p(\d+)\./)[0][1]

    if (tx_release != gtf_release) error "Transcript FASTA release v${tx_release} and GTF release v${gtf_release} differ"
    if (tx_release != current_gencode_release) error "Local GENCODE release v${tx_release} does not match current Human release v${current_gencode_release}. Download the current ALL files from https://www.gencodegenes.org/human/"
    if (genome_patch != current_grch38_patch) error "Local genome assembly GRCh38.p${genome_patch} does not match current GRCh38.p${current_grch38_patch}"

    [tx, genome, gtf]
}

def derived_reference(path) {
    def raw_dir = file(path, type: 'dir', checkIfExists: true)
    def derived_dir = file("${raw_dir.parent}/derived")
    def gentrome = file("${derived_dir}/gentrome.fa")
    def decoys = file("${derived_dir}/decoys.txt")
    def gtf = file("${derived_dir}/annotation.gtf.gz")
    def index = file("${derived_dir}/salmon_index", type: 'dir')
    def index_meta = file("${derived_dir}/salmon_index/info.json")
    [derived_dir, gentrome, decoys, gtf, index, index_meta]
}

def derived_reference_complete(path) {
    def d = derived_reference(path)
    d[1].exists() && d[2].exists() && d[3].exists() && d[4].exists() && d[5].exists()
}

workflow {
    if (!params.samplesheet) error "Provide --samplesheet"

    def rows = parse_samplesheet(params.samplesheet)
    def refs = validate_reference_dir(params.reference_dir)
    def derived = derived_reference(params.reference_dir)

    samples = Channel.fromList(rows)
    reference_inputs = Channel.value(tuple(file(refs[0]), file(refs[1]), file(refs[2])))

    FASTQC(samples)
    MULTIQC(FASTQC.out.reports.collect())

    if (!params.rebuild_reference && derived_reference_complete(params.reference_dir)) {
        log.info "Reusing derived reference and Salmon index under ${derived[0]}"
        reference_gtf = Channel.value(file(derived[3]))
        salmon_index = Channel.value(tuple(file(derived[4], type: 'dir'), file(derived[5])))
    } else {
        log.info "Building derived reference and Salmon index from ${params.reference_dir}"
        BUILD_FULL_DECOY_REFERENCE(MULTIQC.out.report, reference_inputs)
        SALMON_INDEX(BUILD_FULL_DECOY_REFERENCE.out.reference)
        reference_gtf = BUILD_FULL_DECOY_REFERENCE.out.gtf
        salmon_index = SALMON_INDEX.out.index
    }

    SALMON_QUANT(samples, salmon_index)
    quant_dirs = SALMON_QUANT.out.quant_dirs.map { sample, quant_dir -> quant_dir }
    TXIMPORT(quant_dirs.collect(), reference_gtf, file(params.samplesheet, checkIfExists: true))
    RAW_COUNT_SUMMARY(quant_dirs.collect(), TXIMPORT.out.gene_counts)
}
