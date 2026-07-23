#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)

value_after <- function(flag) {
  idx <- match(flag, args)
  if (is.na(idx) || idx == length(args)) stop("Missing required argument: ", flag, call. = FALSE)
  args[[idx + 1]]
}

or_na <- function(x) {
  if (is.null(x) || length(x) == 0) NA_real_ else x
}

values_after <- function(flag) {
  idx <- match(flag, args)
  if (is.na(idx)) stop("Missing required argument: ", flag, call. = FALSE)
  end <- which(seq_along(args) > idx & grepl("^--", args))
  end <- if (length(end)) min(end) - 1 else length(args)
  args[(idx + 1):end]
}

read_samplesheet <- function(path) {
  sep <- if (grepl("\\.tsv$", path, ignore.case = TRUE)) "\t" else ","
  fread(path, sep = sep, na.strings = character(), showProgress = FALSE)
}

quant_dirs <- values_after("--quant_dirs")
gene_counts <- value_after("--gene_counts")
samplesheet <- value_after("--samplesheet")
outdir <- value_after("--outdir")

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
samples <- read_samplesheet(samplesheet)
expected <- as.character(samples$sample)

counts <- fread(gene_counts, showProgress = FALSE)
if (!"gene_id" %in% names(counts)) stop("gene_counts.tsv is missing gene_id", call. = FALSE)
missing_cols <- setdiff(expected, names(counts))
if (length(missing_cols)) stop("gene_counts.tsv missing sample column(s): ", paste(missing_cols, collapse = ", "), call. = FALSE)

mat <- as.matrix(counts[, ..expected])
mode(mat) <- "numeric"
if (any(!is.finite(mat))) stop("Estimated-count matrix contains non-finite values", call. = FALSE)

summary <- data.table(
  metric = c(
    "genes",
    "samples",
    "total_estimated_fragments",
    "median_estimated_fragments_per_gene",
    "genes_with_estimated_count_gt_0",
    "genes_with_estimated_count_ge_10"
  ),
  value = c(
    nrow(counts),
    length(expected),
    sum(mat),
    if (length(mat)) median(rowSums(mat)) else 0,
    sum(rowSums(mat) > 0),
    sum(rowSums(mat) >= 10)
  )
)
fwrite(summary, file.path(outdir, "estimated_count_summary.tsv"), sep = "\t")

gene_summary <- data.table(
  sample = expected,
  total_estimated_fragments = colSums(mat),
  genes_with_estimated_count_gt_0 = colSums(mat > 0)
)
fwrite(gene_summary, file.path(outdir, "gene_count_summary.tsv"), sep = "\t")

mapping_rows <- lapply(expected, function(sample) {
  qdir <- quant_dirs[basename(quant_dirs) == sample]
  if (length(qdir) != 1) stop("Expected exactly one quantification directory for sample: ", sample, call. = FALSE)
  meta_path <- file.path(qdir, "aux_info", "meta_info.json")
  if (!file.exists(meta_path)) stop("Missing Salmon meta_info.json for sample: ", sample, call. = FALSE)
  meta <- fromJSON(meta_path)
  data.table(
    sample = sample,
    num_processed = as.numeric(or_na(meta$num_processed)),
    num_mapped = as.numeric(or_na(meta$num_mapped)),
    percent_mapped = as.numeric(or_na(meta$percent_mapped))
  )
})

mapping <- rbindlist(mapping_rows)
if (nrow(mapping) != length(expected)) stop("Mapping summary does not contain one row per sample", call. = FALSE)
fwrite(mapping, file.path(outdir, "salmon_mapping_summary.tsv"), sep = "\t")
