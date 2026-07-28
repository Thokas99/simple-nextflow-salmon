#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(tximport)
})

args <- commandArgs(trailingOnly = TRUE)

value_after <- function(flag, required = TRUE) {
  idx <- match(flag, args)
  if (is.na(idx) || idx == length(args)) {
    if (required) stop("Missing required argument: ", flag, call. = FALSE)
    return(NA_character_)
  }
  args[[idx + 1]]
}

values_after <- function(flag) {
  idx <- match(flag, args)
  if (is.na(idx)) stop("Missing required argument: ", flag, call. = FALSE)
  end <- which(seq_along(args) > idx & grepl("^--", args))
  end <- if (length(end)) min(end) - 1 else length(args)
  args[(idx + 1):end]
}

parse_attr <- function(x, key) {
  pattern <- paste0(key, ' "([^"]+)"')
  hit <- regexec(pattern, x)
  value <- regmatches(x, hit)
  vapply(value, function(v) if (length(v) == 2) v[[2]] else NA_character_, character(1))
}

read_samplesheet <- function(path) {
  sep <- if (grepl("\\.tsv$", path, ignore.case = TRUE)) "\t" else ","
  dt <- fread(path, sep = sep, na.strings = character(), showProgress = FALSE)
  required <- c("sample", "fastq_1", "fastq_2")
  missing <- setdiff(required, names(dt))
  if (length(missing)) stop("Samplesheet missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  dt[, sample := as.character(sample)]
  dt
}

quant_dirs <- values_after("--quant_dirs")
gtf <- value_after("--gtf")
samplesheet <- value_after("--samplesheet")
outdir <- value_after("--outdir")

if (!length(quant_dirs)) stop("No quantification directories supplied", call. = FALSE)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

samples <- read_samplesheet(samplesheet)
expected <- unique(samples$sample)

quant_paths <- file.path(quant_dirs, "quant.sf")
names(quant_paths) <- basename(quant_dirs)

missing_quant <- setdiff(expected, names(quant_paths))
extra_quant <- setdiff(names(quant_paths), expected)
if (length(missing_quant)) stop("Missing quantification directory for sample(s): ", paste(missing_quant, collapse = ", "), call. = FALSE)
if (length(extra_quant)) stop("Unexpected quantification directory for sample(s): ", paste(extra_quant, collapse = ", "), call. = FALSE)

quant_paths <- quant_paths[expected]
missing_files <- quant_paths[!file.exists(quant_paths)]
if (length(missing_files)) stop("Missing quant.sf file(s): ", paste(missing_files, collapse = ", "), call. = FALSE)
if (anyDuplicated(normalizePath(quant_paths))) stop("Duplicated quant.sf paths supplied", call. = FALSE)

gtf_lines <- readLines(gzfile(gtf), warn = FALSE)
tx_lines <- gtf_lines[grepl("\ttranscript\t", gtf_lines, fixed = TRUE)]
tx_annotation <- data.table(
  transcript_id = parse_attr(tx_lines, "transcript_id"),
  gene_id = parse_attr(tx_lines, "gene_id"),
  gene_name = parse_attr(tx_lines, "gene_name"),
  gene_type = parse_attr(tx_lines, "gene_type")
)
tx2gene <- unique(
  tx_annotation[
    !is.na(transcript_id) & !is.na(gene_id),
    .(transcript_id, gene_id)
  ]
)
if (!nrow(tx2gene)) stop("No transcript_id/gene_id mappings found in GTF", call. = FALSE)
if (tx2gene[, .N, transcript_id][N > 1L, .N]) stop("A transcript_id maps to multiple gene_id values", call. = FALSE)

gene_annotation <- unique(
  tx_annotation[
    !is.na(gene_id),
    .(gene_id, gene_name)
  ]
)
conflicts <- gene_annotation[
  !is.na(gene_name) & gene_name != "",
  .(names = paste(sort(unique(gene_name)), collapse = ", "), n_names = uniqueN(gene_name)),
  by = gene_id
][n_names > 1L]
if (nrow(conflicts)) {
  examples <- conflicts[seq_len(min(.N, 5L)), paste0(gene_id, " -> ", names)]
  stop("Conflicting gene_name values for gene_id: ", paste(examples, collapse = "; "), call. = FALSE)
}
gene_annotation <- gene_annotation[
  ,
  .(gene_name = {
    names <- unique(gene_name[!is.na(gene_name) & gene_name != ""])
    if (length(names)) names[1] else gene_id[1]
  }),
  by = gene_id
]
gene_annotation[is.na(gene_name) | gene_name == "", gene_name := gene_id]
if (gene_annotation[, anyDuplicated(gene_id)]) stop("gene_annotation must contain one row per gene_id", call. = FALSE)
observed_tx <- unique(unlist(lapply(quant_paths, function(path) fread(path, select = "Name", showProgress = FALSE)$Name)))
overlap <- length(intersect(observed_tx, tx2gene$transcript_id))
overlap_fraction <- overlap / max(1, length(observed_tx))
if (overlap_fraction < 0.50) {
  stop(sprintf("Transcript overlap too low: %d/%d (%.1f%%)", overlap, length(observed_tx), 100 * overlap_fraction), call. = FALSE)
}

txi <- tximport(quant_paths, type = "salmon", tx2gene = tx2gene, countsFromAbundance = "no")
counts <- as.data.table(txi$counts, keep.rownames = "gene_id")
abundance <- as.data.table(txi$abundance, keep.rownames = "gene_id")
lengths <- as.data.table(txi$length, keep.rownames = "gene_id")

setorderv(counts, "gene_id")
setorderv(abundance, "gene_id")
setorderv(lengths, "gene_id")
setcolorder(counts, c("gene_id", expected))
setcolorder(abundance, c("gene_id", expected))
setcolorder(lengths, c("gene_id", expected))

mat <- as.matrix(counts[, ..expected])
if (!is.numeric(mat) || any(!is.finite(mat))) stop("Gene estimated-count matrix contains non-finite values", call. = FALSE)

add_gene_names <- function(dt) {
  annotated <- gene_annotation[dt, on = "gene_id"]
  annotated[is.na(gene_name) | gene_name == "", gene_name := gene_id]
  setcolorder(annotated, c("gene_id", "gene_name", expected))
  annotated[]
}

counts <- add_gene_names(counts)
abundance <- add_gene_names(abundance)
lengths <- add_gene_names(lengths)

fwrite(counts, file.path(outdir, "salmon_gene_estimated_counts.tsv"), sep = "\t")
fwrite(abundance, file.path(outdir, "salmon_gene_tpm.tsv"), sep = "\t")
fwrite(lengths, file.path(outdir, "salmon_gene_average_effective_length.tsv"), sep = "\t")
fwrite(tx2gene[order(transcript_id)], file.path(outdir, "tx2gene.tsv"), sep = "\t")
fwrite(gene_annotation[order(gene_id)], file.path(outdir, "gene_annotation.tsv"), sep = "\t")
fwrite(samples, file.path(outdir, "sample_metadata.tsv"), sep = "\t")
fwrite(data.table(
  metric = c("samples", "genes", "transcripts_in_quant", "transcripts_in_gtf", "transcript_overlap", "transcript_overlap_fraction", "countsFromAbundance"),
  value = c(length(expected), nrow(counts), length(observed_tx), nrow(tx2gene), overlap, sprintf("%.6f", overlap_fraction), "no")
), file.path(outdir, "tximport_summary.tsv"), sep = "\t")
saveRDS(
  txi,
  file.path(outdir, "salmon_gene_tximport.rds"),
  compress = "xz"
)
