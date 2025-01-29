#!/usr/bin/env Rscript

library(tidyverse)
library(duckdb)
library(dplyr)
library(ggplot2)
library(RColorBrewer)
library(paletteer)
library(cowplot)
library(ggfortify)
library(ggpubr)

DBFILE="fungigenomeDB.duckdb"

# to use a database file already created by
con <- dbConnect(duckdb(), dbdir=DBFILE, read_only = TRUE)

aafreq_sql ="
SELECT sp.*, aaf.*, stats.GC_PERCENT, stats.TOTAL_LENGTH
FROM
species as sp,
aa_frequency as aaf,
asm_stats as stats
WHERE
sp.LOCUSTAG = aaf.species_prefix AND
sp.LOCUSTAG = stats.LOCUSTAG"

# RUN the SQL query from ABOVE
aafreq_res <- dbGetQuery(con, aafreq_sql)
head(aafreq_res)

# MOVE FROM LONG TO WIDE FORMAT
# REMOVE EMPTY PHYLUM
aafreq_wide <- aafreq_res %>% select(c(PHYLUM,SUBPHYLUM,CLASS,GENUS,SPECIES,GC_PERCENT,TOTAL_LENGTH,LOCUSTAG,amino_acid, frequency)) %>%
  filter(! is.na(PHYLUM)) %>%
  pivot_wider(id_cols = c(PHYLUM,SUBPHYLUM,CLASS,GENUS,SPECIES,GC_PERCENT,TOTAL_LENGTH,LOCUSTAG),
              names_from = amino_acid, values_from = frequency)
head(aafreq_wide)

# reformat for PCA processing
aa_pcadat <- as.matrix(aafreq_wide %>% select(-c(PHYLUM,SUBPHYLUM,CLASS,GENUS,SPECIES,GC_PERCENT,TOTAL_LENGTH,LOCUSTAG,X)))
rownames(aa_pcadat) <- aafreq_wide$LOCUSTAG

# create a PCA from the data 
aa_pca_res <- prcomp(aa_pcadat, scale. = TRUE)

# create the PCA plot in ggplot color by PHYLUM
aa_pcaplot<- autoplot(aa_pca_res, data = aafreq_wide, colour = 'PHYLUM', alpha=0.7,
                      label = FALSE, label.size = 3) +
  theme_cowplot(12) + scale_colour_brewer(palette = "Set1")
aa_pcaplot
ggsave(file.path(statsplotdir,"PCA_aa_freq_all.pdf"),aa_pcaplot,width=14,height=14)

# capture the PCA factors
aa_pcafactors <- as_tibble(rownames_to_column(data.frame(aa_pca_res$x),var="LOCUSTAG"))

# fit the 
aa_pca_factors <- aafreq_wide %>% left_join(aa_pcafactors,by="LOCUSTAG")
fit <- lm(PC1~GC_PERCENT,aa_pca_factors%>%select(c(GC_PERCENT,PC1)))

aa_GC_plot <- ggplot(aa_pca_factors,aes(x=GC_PERCENT,y=PC1)) + geom_point(aes(color=PHYLUM,fill=PHYLUM)) +
  theme_cowplot(12) + scale_colour_brewer(palette = "Set1") +
  geom_smooth(method = "lm", se = FALSE,color="black",formula = y ~ x) +
  xlab("Genome GC %") +
  ylab("AA Freq PC1") +
  ggtitle(paste("GC % vs AA Freq PC1",
                "Adj R2 = ",signif(summary(fit)$adj.r.squared, 5),
                "Intercept =",signif(fit$coef[[1]],5 ),
                " Slope =",signif(fit$coef[[2]], 5),
                " p-value =",signif(summary(fit)$coef[2,4], 5))) +
  theme(legend.position="bottom")
aa_GC_plot
ggsave("PCA_AA_freq_PC1_GC.pdf",aa_GC_plot,width=14,height=14)

aa_pca_factors$SUBPHYLUM <- factor(aa_pca_factors$SUBPHYLUM)
aa_pca_factors$PHYLUM <- factor(aa_pca_factors$PHYLUM)

aa_GC_plot_f <- ggplot(aa_pca_factors,aes(x=GC_PERCENT,y=PC1)) + geom_point(aes(color=SUBPHYLUM)) +
  theme_cowplot(12) +
  geom_smooth(method = "lm", se = FALSE,color="black",formula = y ~ x) +
  xlab("Genome GC %") +
  ylab("AA Freq PC1") +
  ggtitle("GC % vs AA Freq PC1") +
  theme(legend.position="bottom")  + facet_wrap(~PHYLUM )
aa_GC_plot_f
ggsave("PCA_AA_freq_PC1_GC_facet.pdf",aa_GC_plot_f,width=14,height=14)

# closeup shop
dbDisconnect(con, shutdown = TRUE)