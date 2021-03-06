# loading required libraries
library(tidyverse)
library(xtable)
library(SummarizedExperiment)

# loading data
binding_data <- read_rds('autoreg/data/binding_data.rds')
dep_res <- read_rds('autoreg/data/dep_res.rds')
go_annotation <- read_rds('autoreg/data/go_annotation.rds')
tf_annotation <- read_rds('autoreg/data/tf_annotation.rds')

# defining variables
ind <- intersect(go_annotation$SYMBOL, tf_annotation$SYMBOL)

peak_symbol <- map(binding_data, function(x){
  tibble(row = mcols(x)$name,
         gene_id = mcols(x)$geneId)
}) %>%
  bind_rows() %>%
  unique() %>%
  filter(gene_id %in% ind)

header <- paste0("\\multirow{2}[3]{*}{Category} & \\multirow{2}[3]{*}{Factor} & \\multirow{2}[3]{*}{Gene} &",
  " \\multicolumn{4}{c}{Early vs Non} & \\multicolumn{4}{c}{Late vs Non} &  \\multicolumn{4}{c}{Late vs Early} \\\\",
  " \\cmidrule(lr){4-7} \\cmidrule(lr){8-11} \\cmidrule(lr){12-15}",
  "&&& (N) & Range & Ave & SD & (N) & Range & Ave & SD & (N) & Range & Ave & SD \\\\")

cat_fac <- list(factor = c('CEBPB', 'PPARG'),
                co_factor = c('EP300', 'MED1', 'RXRG'),
                hm = c('H3K27ac', 'H3K4me3'))
fac <- tibble(cat = factor(rep(c('Factor', 'Cofactor', 'Histone Marker'), times = c(2,3,2)),
                           levels = c('Factor', 'Cofactor', 'Histone Marker')),
       factor = factor(unlist(cat_fac, use.names = FALSE),
                       levels = unlist(cat_fac, use.names = FALSE)))

# generating table
peak_symbol %>%
  inner_join(dep_res) %>%
  filter(padj < .2) %>%
  group_by(factor, contrast, gene_id) %>%
  summarise(n = n(),
            range = ifelse(n() == 1, as.character(round(log2FoldChange, 2)),
                           paste(round(min(log2FoldChange), 2), round(max(log2FoldChange), 2), sep = '/')),
            ave = round(mean(log2FoldChange), 2),
            sd = ifelse(is.na(sd(log2FoldChange)), '', as.character(round(sd(log2FoldChange), 2)))) %>%
  unite(values, n, range, ave, sd, sep = '_') %>%
  spread(contrast, values) %>%
  ungroup() %>%
  right_join(fac) %>%
  dplyr::select(cat, factor, gene = gene_id, early_vs_non, late_vs_non, late_vs_early) %>%
  separate(early_vs_non, sep = '_', into = c('n1', 'range1', 'ave1', 'sd1')) %>%
  separate(late_vs_non, sep = '_', into = c('n2', 'range2', 'ave2', 'sd2')) %>%
  separate(late_vs_early, sep = '_', into = c('n3', 'range3', 'ave3', 'sd3')) %>%
  mutate(factor = ifelse(duplicated(factor), '', factor)) %>%
  mutate(cat = ifelse(duplicated(cat), '', as.character(cat))) %>%
  xtable(align = 'clllcccccccccccc') %>%
  print(floating = FALSE,
        include.rownames = FALSE,
        booktabs = TRUE,
        sanitize.text.function = identity,
        comment = FALSE,
        include.colnames=FALSE,
        add.to.row = list(pos = list(0, 2, 4, 8, 12, 3, 11),
                          command = c(header, rep('\\cmidrule{2-15} ', 4), rep('\\midrule ', 2))),
        file = 'manuscript/tables/dep_fc.tex')

#caption = 'Significant peaks of adipogenic factors on autophagy transcription factor genes.',
#label = 'tab:dep_fc',
