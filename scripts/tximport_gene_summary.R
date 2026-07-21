#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(readr)
  library(tximport)
})

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

gtf <- value_after("--gtf")
samplesheet <- value_after("--samplesheet")
outdir <- value_after("--outdir", "tximport")
if (is.null(gtf) || is.null(samplesheet)) stop("Usage: --gtf annotation.gtf.gz --samplesheet samplesheet.csv --outdir tximport", call. = FALSE)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

read_table_auto <- function(path) {
  first <- readLines(path, n = 1)
  delim <- if (grepl("\t", first, fixed = TRUE)) "\t" else ","
  read_delim(path, delim = delim, show_col_types = FALSE, progress = FALSE)
}

samples <- read_table_auto(samplesheet)
needed <- c("sample", "fastq_1", "fastq_2")
if (!all(needed %in% names(samples))) stop("samplesheet must contain sample, fastq_1, fastq_2", call. = FALSE)
sample_ids <- samples$sample

quant_files <- file.path(sample_ids, "quant.sf")
missing <- quant_files[!file.exists(quant_files)]
if (length(missing)) stop("Missing quant.sf files: ", paste(missing, collapse = ", "), call. = FALSE)
names(quant_files) <- sample_ids

gtf_dt <- fread(cmd = paste("gzip -cd", shQuote(gtf)), sep = "\t", header = FALSE, quote = "")
gtf_dt <- gtf_dt[V3 == "transcript"]
attrs <- gtf_dt$V9
extract_attr <- function(x, key) sub(sprintf('.*%s "([^"]+)".*', key), "\\1", x)
tx2gene <- unique(data.table(
  TXNAME = extract_attr(attrs, "transcript_id"),
  GENEID = extract_attr(attrs, "gene_id")
))
tx2gene <- tx2gene[TXNAME != GENEID]
fwrite(tx2gene, file.path(outdir, "tx2gene.tsv"), sep = "\t")

quant_tx <- fread(quant_files[[1]], nrows = 1000)$Name
overlap <- mean(quant_tx %in% tx2gene$TXNAME)
if (is.na(overlap) || overlap < 0.8) {
  stop(sprintf("Low quant.sf/GTF transcript ID overlap: %.1f%%. Check Salmon --gencode and matching GENCODE files.", 100 * overlap), call. = FALSE)
}

txi <- tximport(quant_files, type = "salmon", tx2gene = tx2gene, countsFromAbundance = "no")

fwrite(as.data.table(txi$counts, keep.rownames = "gene_id"), file.path(outdir, "gene_counts.tsv"), sep = "\t")
fwrite(as.data.table(txi$abundance, keep.rownames = "gene_id"), file.path(outdir, "gene_abundance.tsv"), sep = "\t")
fwrite(as.data.table(txi$length, keep.rownames = "gene_id"), file.path(outdir, "gene_length.tsv"), sep = "\t")
fwrite(as.data.table(samples), file.path(outdir, "sample_metadata.tsv"), sep = "\t")
saveRDS(txi, file.path(outdir, "tximport_object.rds"))
