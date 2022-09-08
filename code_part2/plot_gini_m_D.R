# plot_gini_m_D

# Makes figure 2, which consists of showing gini (Lorenz Curve), portability,
# and PGS Divergence

### Libraries and directories ####
library(tidyverse)
library(ggpubr)
library(ggrepel)
library(data.table)
source("../code_part1/helper_functions.R")

# sets working directory
setwd("./")

# Sets the directory of the summary files with appended allele frequencies
dir_sfs <- "../generated_data/betas_and_AFs/"
# location to a file we generated that vastly speeds up the process of binning
# can be obtained from our github under ~/generated_data/
loc_chr_max_bps <- "../code_part1/chr_max_bps.txt"
# Sets the location of the sampled individuals' PRSs
loc_PRSs <- "../generated_data/pop_sampled_PRSs.txt"
# sets the location of the traits table
loc_table <- "../generated_data/traits_table.txt"
# sets directory of outputted figures
dir_out <- "../generated_figures/"

# sets scaling factors for image output. Default = 2
sf <- 2

### Functions ####

# function that sets a common theme for plots:
common_theme <- theme_light() +
  theme(
  aspect.ratio = 1,
  panel.grid.major = element_blank(),
  panel.grid.minor = element_blank(),
  panel.border = element_rect(colour = "black", fill=NA, size=1),
  plot.title = element_text(hjust = 0.5, size=9*sf),
  axis.title = element_text(size=7*sf),
  axis.text = element_text(size=6*sf),
  legend.title = element_text(size=7*sf),
  legend.text = element_text(size=6*sf)
)

# function that reads a trait's summary file and extracts the needed columns
cleanup_data_lorenz <- function(code, ancestry="United", threshold=100, threshold_padding=TRUE, bin_size=100000, bin_summary_method="sum") {
  col_AF <- paste0("VarFreq_",ancestry)
  
  loc_sf <- paste0(dir_sfs,code,"-betasAFs.txt")
  sf <- as_tibble(fread(loc_sf)) %>%
    bin_snps(bin_size) %>%
    get_h2("effect_weight", col_AF) %>%
    get_data_binned(bin_summary_method) %>%
    arrange(-h2) %>%
    filter(row_number() <= threshold) %>%
    arrange(h2) %>%
    mutate(h2_csum = cumsum(h2)) %>%
    select(h2,h2_csum)
  sf$h2_cshare <- sf$h2_csum / sf$h2_csum[nrow(sf)]
  if ((nrow(sf) < threshold) & (threshold_padding)) {
    sf <- sf %>%
      add_row(
        h2 = rep(0, threshold - nrow(sf)),
        h2_csum = rep(0, threshold - nrow(sf)),
        h2_cshare = rep(0, threshold - nrow(sf)),
      ) %>% arrange(h2)
  }
  sf <- sf %>%
    mutate(percentile = row_number() / nrow(sf))
  sf
}
# function that actually plots Lorenz curve
plot_lorenz <- function(code, sfile, ancestry="United") {
  
  slice <- traits_table %>% filter(prive_code == code)
  description <- slice$description
  gini <- slice[1,paste0("gini_",ancestry)]
  
  if (ancestry=="United") {ancestry <- "UK"}
  
  title <- paste0(description)
  gini_text <- formatC(gini[[1]],digits=3, format="f")
  #subtitle <- bquote(Gini[100][','][UK]==.(gini_text))
  text <- paste0("Gini[100][','][UK]==",gini_text)
  
  
  gg<-ggplot(sfile, aes(x=100*percentile, y=h2_cshare)) +
    geom_col(position = position_nudge(-0.5), fill="gray20", width=0.8) +
    geom_abline(slope=1/100,color="dodgerblue1") +
    labs(title=title) +
    xlab(expression(paste("Percentile of summed ",italic(gvc)," for each bin"))) +
    ylab(expression(paste("Cumulative sum of bin ",italic(gvc)))) +
    theme_light() +
    common_theme +
    scale_x_continuous(limits=c(0,100), expand = c(0.0,0.0)) +
    scale_y_continuous(limits=c(0,1), expand = c(0,0))
  
  xrange <- layer_scales(gg)$x$range$range
  yrange <- layer_scales(gg)$y$range$range
  gg <- gg +
    annotate("text",
             x = 0.5 * 100, #x=0.025*(100),
             y = 0.975*(1), label = text,
             parse=TRUE, vjust=1, hjust=0.5, size=3*sf)
    
  gg
}
# function that plots portability
plot_portability <- function(code) {
  pcor_data <- traits_table %>% filter(prive_code == code) %>%
    select(starts_with("pcor_")) %>%
    pivot_longer(
      cols = starts_with("pcor_"),
      names_prefix = "pcor_",
      names_to = "ancestry",
      values_to = "pcor"
    ) %>% mutate(
      sup = traits_table %>% filter(prive_code == code) %>%
        select(starts_with("sup_")) %>% unlist(),
      inf = traits_table %>% filter(prive_code == code) %>%
        select(starts_with("inf_")) %>% unlist()
    ) %>% mutate(
      relative_pcor = pcor / (traits_table %>% filter(prive_code == code))$pcor_United[1],
      relative_sup = sup / (traits_table %>% filter(prive_code == code))$pcor_United[1],
      relative_inf = inf / (traits_table %>% filter(prive_code == code))$pcor_United[1]
    ) %>% left_join(distances, by="ancestry")
  pcor_data[pcor_data$ancestry=="United","ancestry"] <- "UK"
  
  slice <- traits_table %>% filter(prive_code == code)
  m <- slice$portability_index
  description <- slice$description
  subtitle <- paste0("m = ", formatC(m, digits=5, format="f"))
  text <- paste0("m==",formatC(m, digits=5, format="f"))
  
  gg<-ggplot(pcor_data, aes(x=prive_dist_to_UK)) +
    geom_segment(aes(x=0,y=1, xend=max(prive_dist_to_UK), yend=1 + m * max(prive_dist_to_UK)),
                 size=1, color="dodgerblue1") +
    geom_point(aes(y = relative_pcor)) +
    geom_errorbar(aes(ymin = relative_inf, ymax = relative_sup)) +
    geom_text_repel(aes(label = ancestry, y = relative_pcor), seed=1, direction="x", size=2.25*sf) +
    scale_x_continuous(expand=expansion(mult = c(0.01, .01))) +
    scale_y_continuous(limits = c(0,max(1,max(pcor_data$relative_sup))),
                       expand=expansion(mult = c(0, .01))) +
    common_theme +
    xlab("Genetic PC Distance to UK") +
    ylab("PGS Accuracy Relative to UK") +
    labs(title = description)
  
  xrange <- layer_scales(gg)$x$range$range
  yrange <- layer_scales(gg)$y$range$range
  gg <- gg +
    annotate("text",
             x=0.5*(xrange[2]-xrange[1]), #x=0.975*(xrange[2]-xrange[1]),
             y = 0.975*(yrange[2]-0), label = text,
             parse=TRUE, vjust=1, hjust=0.5, size=3*sf)
  gg
}
# function that generates divergence plot
plot_divergence <- function(code) {
  
  # extracts info about trait
  PRS_trait <- PRSs %>% select(Ancestry = ancestry, PRS = all_of(code))
  slice <- traits_table %>% filter(prive_code == code)
  description <- slice$description[1]
  f_stat <- slice$f_stat[1]
  p_value <- slice$p_value_f[1]
  logfstat <- formatC(log10(f_stat),digits=2, format="f")
  
  # converts p-value to more legible text
  if (p_value < 1E-320) {
    p_text <- "< 1E-320"
    p_text <- bquote(D==.(logfstat)~~~~~p-value<10^{-320})
    #text <- paste0("D==",logfstat,"~p-value<10^-320")
  } else {
    p_text <- formatC(p_value,format="E", digits=2)
    p_text_stem <- as.numeric(substr(p_text,1,4))
    p_text_exp <- as.numeric(substr(p_text,6,10))
    p_text <- bquote(D==.(logfstat)~~~~~p-value==.(p_text_stem)%*%10^{.(p_text_exp)})
    #text <- paste0("D==",logfstat,"~p-value==",p_text_stem,"%*%10^",p_text_exp)
  }
  text <- paste0("D==",logfstat)
  
  # plots divergence
  gg<-ggplot(PRS_trait, aes(x=PRS, fill=Ancestry)) +
    geom_density(color='#e9ecef', alpha=0.6, position='identity') +
    theme_light() +
    common_theme +
    theme(legend.position = "bottom",
          #legend.title=element_blank(),
          legend.title.align = 0.5,
          axis.text.y = element_blank(),
          axis.ticks.y = element_blank()) +
    xlab("Polygenic Score per UKBB Individual") +
    ylab("Density") +
    scale_x_continuous(expand=expansion(mult = c(0, 0))) +
    scale_y_continuous(expand=expansion(mult = c(0, 0.01))) +
    labs(title=paste0(description))
  xrange <- layer_scales(gg)$x$range$range
  yrange <- layer_scales(gg)$y$range$range
  gg <- gg +
    annotate("text",
             x=(xrange[2]+xrange[1])/2, #x=0.975*(xrange[2]-xrange[1])+xrange[1],
             y = 0.975*(yrange[2]-0), label = text,
             parse=TRUE, vjust=1, hjust=0.5, size=3*sf)
  gg
}
### Code ####

# reads traits table
traits_table <- as_tibble(fread(loc_table))

# loads a file that contains the max base pair position for each chromosome
chr_max_bps <- as_tibble(fread(loc_chr_max_bps))

# reads pop_centers, which contains PC distance information
pop_centers <- read.csv(
  "https://raw.githubusercontent.com/privefl/UKBB-PGS/main/pop_centers.csv",
  stringsAsFactors = FALSE)
ancestries <- sort(pop_centers$Ancestry)
ancestries[9] <- "United" # in order to match other data
prive_PC <- pop_centers %>% select(PC1:PC16)
prive_dist_to_UK <- as.matrix(dist(prive_PC))[,1]
distances <- tibble(
  ancestry = pop_centers$Ancestry,
  prive_dist_to_UK = prive_dist_to_UK
) %>% arrange(ancestry)
distances$ancestry <- str_replace(distances$ancestry,"United Kingdom","United")

# reads the PRSs and changes "United" to "UK"
PRSs <- as_tibble(fread(loc_PRSs)) %>% filter(ancestry != "Ashkenazi")
PRSs[PRSs$ancestry=="United","ancestry"] <- "UK"

# settings used for plotting Lorenz. Deviation from these (other than ancestry)
# will lead to the displayed Gini score on the plot being incorrect
ancestry <- "United"
threshold <- 100
threshold_padding <- FALSE
bin_size <- 100000
bin_summary_method <- "sum"

## makes Lorenz plots
low_gini_code <- "geek_time"
low_gini_sf <- cleanup_data_lorenz(low_gini_code, ancestry, threshold, threshold_padding, bin_size, bin_summary_method)
low_gini_plot <- plot_lorenz(low_gini_code, low_gini_sf, ancestry)

high_gini_code <- "275.1"
high_gini_sf <- cleanup_data_lorenz(high_gini_code, ancestry, threshold, threshold_padding, bin_size, bin_summary_method)
high_gini_plot <- plot_lorenz(high_gini_code, high_gini_sf, ancestry)

## makes portability plots
low_m_code <- "log_bilirubin"
low_m_plot <- plot_portability(low_m_code)

high_m_code <- "haemoglobin"
high_m_plot <- plot_portability(high_m_code)

## makes divergence plots
low_D_code <- "250.1"
low_D_plot <- plot_divergence(low_D_code) +
  theme(legend.justification = c(0,1),
        legend.position = c(0.01, 0.99),
        legend.background = element_rect(fill=NULL))

high_D_code <- "darker_skin0"
high_D_plot <- plot_divergence(high_D_code) +
  theme(legend.position = "none")

## arranges all plots together
plots <- list(low_gini_plot , low_m_plot , low_D_plot,
              high_gini_plot, high_m_plot, high_D_plot)

ggarrange(plotlist = plots, ncol = 3, nrow = 2)

# plot save settings for each plot (in pixels)
width <- 1100
height <- 1100

loc_out <- paste0(dir_out,"figure_2.png")
ggsave(loc_out,width=3*width*sf,height=2*height*sf,units="px")