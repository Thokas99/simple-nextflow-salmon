#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

gene_counts_file <- value_after("--gene_counts")
outdir <- value_after("--outdir", "summary")
if (is.null(gene_counts_file)) stop("Usage: --gene_counts gene_counts.tsv --outdir summary", call. = FALSE)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

as_na <- function(x) if (is.null(x) || length(x) == 0) NA else x

quant_files <- list.files(".", pattern = "quant\\.sf$", recursive = TRUE, full.names = TRUE)
mapping <- rbindlist(lapply(quant_files, function(qf) {
  sample <- basename(dirname(qf))
  meta_file <- file.path(dirname(qf), "aux_info", "meta_info.json")
  lib_file <- file.path(dirname(qf), "lib_format_counts.json")
  meta <- if (file.exists(meta_file)) fromJSON(meta_file, simplifyVector = TRUE) else list()
  lib <- if (file.exists(lib_file)) fromJSON(lib_file, simplifyVector = TRUE) else list()
  data.table(
    sample = sample,
    num_processed = as_na(meta$num_processed),
    num_mapped = as_na(meta$num_mapped),
    mapping_rate = as_na(meta$percent_mapped),
    num_decoy_fragments = as_na(meta$num_decoy_fragments),
    num_dovetail_fragments = as_na(lib$num_dovetail_fragments),
    num_fragments_filtered_vm = as_na(lib$num_fragments_filtered_vm),
    library_type = as_na(meta$library_types),
    compatible_fragment_ratio = as_na(lib$compatible_fragment_ratio),
    salmon_version = as_na(meta$salmon_version)
  )
}), fill = TRUE)
fwrite(mapping, file.path(outdir, "salmon_mapping_summary.tsv"), sep = "\t", na = "NA")

counts <- fread(gene_counts_file)
gene_col <- names(counts)[1]
sample_cols <- setdiff(names(counts), gene_col)
mat <- as.matrix(counts[, ..sample_cols])
storage.mode(mat) <- "numeric"

raw_summary <- rbindlist(lapply(seq_along(sample_cols), function(i) {
  x <- mat[, i]
  nz <- x[x > 0]
  data.table(
    sample = sample_cols[i],
    total_estimated_counts = sum(x, na.rm = TRUE),
    genes_with_count_gt_0 = sum(x > 0, na.rm = TRUE),
    genes_with_count_ge_1 = sum(x >= 1, na.rm = TRUE),
    genes_with_count_ge_10 = sum(x >= 10, na.rm = TRUE),
    median_nonzero_count = if (length(nz)) median(nz, na.rm = TRUE) else NA_real_,
    mean_count = mean(x, na.rm = TRUE),
    max_count = max(x, na.rm = TRUE)
  )
}))
fwrite(raw_summary, file.path(outdir, "raw_count_summary.tsv"), sep = "\t", na = "NA")

gene_summary <- data.table(
  gene_id = counts[[gene_col]],
  total_count = rowSums(mat, na.rm = TRUE),
  mean_count = rowMeans(mat, na.rm = TRUE),
  median_count = apply(mat, 1, median, na.rm = TRUE),
  min_count = apply(mat, 1, min, na.rm = TRUE),
  max_count = apply(mat, 1, max, na.rm = TRUE),
  samples_with_count_gt_0 = rowSums(mat > 0, na.rm = TRUE),
  samples_with_count_ge_10 = rowSums(mat >= 10, na.rm = TRUE)
)
fwrite(gene_summary, file.path(outdir, "gene_count_summary.tsv"), sep = "\t", na = "NA")
