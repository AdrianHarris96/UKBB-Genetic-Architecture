# plot_scatterplot_matrix_density.R

# Plots the 5x5 scatterplot matrix and the dual density plots


### Libraries and directories ####
library(tidyverse)
library(GGally)
library(rlang)

# sets location of trait_table generated in part1
#loc_table <- "../generated_data/traits_table.txt"
loc_table <- "D:/Genee_local/github/nuno_files_2/table_PLR_100k_sum_100_zp.txt"
#dir_out <- "../generated_figures/"
dir_out <- "D:/OneDrive - Georgia Institute of Technology/Lachance/Genee/06-27/"
# sets scaling factors for image output. Default = 2
sf <- 2

### Code ####
traits_table <- as_tibble(read_tsv(loc_table)) %>%
  select(prive_code, trait, description, trait_type, group,
         gini_United, pcor_United, portability_index, ldpred2_h2, f_stat) %>%
  mutate(lifestyle = group == "lifestyle and environment") %>%
  drop_na()

# Caps maximum portability to 0
traits_table[which(traits_table$portability_index > 0),"portability_index"] <- 0
# Log10 transforms F-statistic
traits_table[,"f_stat"] <- log10(traits_table[,"f_stat"])

# Helper function for writing p-values onto plots
digits <- 3 # how many digits to round p-values to (non-scientific notation)
color_p_significant <- "gray20"
color_p_nonsignificant <- "gray50"
p_value_to_text <- function(p_value) {
  p_text <- round(p_value,digits)
  if (p_value < 0.001) {
    stars <- "***"
    p_text <- formatC(p_value,format="e", digits=2)
    text_color = color_p_significant
  } else if (p_value < 0.01) {
    stars <- "**"
    text_color = color_p_significant
  } else if (p_value < 0.05) {
    stars <- "*"
    text_color = color_p_significant
  } else {
    stars <- ""
    text_color = color_p_nonsignificant
  }
  list(p_text,stars,text_color)
}

### Scatterplot Matrix ####

# calculates adjusted p-values for correlation measurement between variables
vars <- c("ldpred2_h2","gini_United","pcor_United","portability_index","f_stat")
p_values_cor <- tibble(
  var1 = as.character(),
  var2 = as.character(),
  cor = as.numeric(),
  unadj_p_value = as.numeric(),
  adj_p_value = as.numeric()
)
for (i in 1:4) {
  x <- vars[[i]]
  for (j in (i+1):5) {
    y <- vars[[j]]
    cor1 <- cor.test(as.data.frame(traits_table)[,x],
                    as.data.frame(traits_table)[,y])
    cor_value <- cor1$estimate[[1]]
    p_value <- cor1$p.value
    p_values_cor <- p_values_cor %>% add_row(
      var1 = x,
      var2 = y,
      cor = cor_value,
      unadj_p_value = p_value,
      adj_p_value = NA
    )
  }
}
# uses False Discovery Rate to adjust p-values
adj_p_values_cor <- p.adjust(p_values_cor$unadj_p_value,"fdr")
p_values_cor$adj_p_value <- adj_p_values_cor

## Matrix subplot functions
# Top-right plots: correlation and p-value between measurements
upper_corr_p <- function(data,mapping) {
  # extracts x and y from ggpairs data argument
  x <- as.character(quo_get_expr(mapping[[1]]))
  y <- as.character(quo_get_expr(mapping[[2]]))
  
  # extracts r- and p-value from previous computations
  slice <- p_values_cor %>% filter( (var1==x & var2==y) | (var1==y & var2==x) )
  cor_value <- slice$cor
  p_value <- slice$adj_p_value
  
  p_text_list <- p_value_to_text(p_value)
  
  # determines full text to display
  text <- paste0("Corr = ", round(cor_value,digits), p_text_list[[2]],
                "\nAdj P = ", p_text_list[[1]])
  
  # makes GGally textplot using custom text
  p <- ggally_text(label=text,
                   color=p_text_list[[3]],
                   size=8*sf) +
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), 
          panel.border = element_rect(linetype = "solid", 
                                      color = theme_get()$panel.background$fill, fill = "transparent"))
  p
}

# Diagonal plots: display name and symbol of variable
var_labels <- c(
  "ldpred2_h2" = "Heritability\n(h^2_SNP)",
  "gini_United"="Polygenicity\n(Gini_100,UK)",
  "pcor_United"="Performance\n(p_UK)",
  "portability_index"="Portability\n(m)",
  "f_stat" = "Divergence\n(log10(F))")
diag_label <- function(data, mapping) {
  variable <- as.character(quo_get_expr(mapping[[1]]))
  
  # makes GGally textplot using custom text
  p <- ggally_text(label=var_labels[[variable]],
                   color="black",
                   size=10*sf) +
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), 
          panel.border = element_rect(linetype = "solid", 
                                      color = "black",
                                      fill = "transparent"))
  p
}

# Bottom-left plots: scatterplot
axis_lims <- list(
  "f_stat" = c(0,3.6),
  "ldpred2_h2" = c(0,1),
  "pcor_United"=c(0,0.64),
  "portability_index"=c(-0.006,0),
  "gini_United"=c(0,1))
lm_scatterplot <- function(data, mapping) {
  x <- as.character(quo_get_expr(mapping[[1]]))
  y <- as.character(quo_get_expr(mapping[[2]]))
  
  xlims <- axis_lims[[x]]
  ylims <- axis_lims[[y]]
  
  p <- ggplot(data=data, mapping=mapping) +
    geom_smooth(method="lm", color="dodgerblue1", formula=y~x, size=1*sf) +
    geom_point(alpha=0.5,shape=19, size=1.75*sf) +
    xlim(xlims) +
    ylim(ylims) +
    theme_light()
  p
}
# Plots actual 5x5 scatterplot matrix
p_5x5 <- ggpairs(data = traits_table,
        columns=names(var_labels),
        lower = list(continuous = lm_scatterplot),
        diag = list(continuous = diag_label),
        upper = list(continuous = upper_corr_p),
        axisLabels = "show"
) +
  theme(strip.text.x = element_blank(),
        strip.text.y = element_blank(),
        text = element_text(size = ddplot_textsize*sf),
        axis.text.x = element_text(size=(ddplot_textsize*0.5)*sf),
        axis.text.y = element_text(size=(ddplot_textsize*0.5)*sf))

# Saves image onto system
smplot_width <- 1200
smplot_height <- 1150
loc_out <- paste0(dir_out,"scatterplot_matrix.png")
png(loc_out, width = smplot_width*sf, height = smplot_height*sf)
print(p_5x5)
dev.off()
print(paste("Saved 5x5 scatterplot matrix"))

### Dual Density Plots ####

column_labels <- c("Heritability","Polygenicity","Performance","Portability","Divergence")

# uses Wilcoxon-ranked test to compare means differences between types and groups
# for each of the 5 measurements
p_values_WRT <- tibble(
  var_measurement = as.character(),
  var_comparison = as.character(),
  unadj_p_value = as.numeric(),
  adj_p_value = as.numeric()
)
for (i in 1:2) {
  if (i==1) {
    var_comparison <- "group"
    subtable1 <- traits_table %>% filter(lifestyle) %>% select(vars)
    subtable2 <- traits_table %>% filter(!lifestyle) %>% select(vars)
  } else if (i==2) {
    var_comparison <- "type"
    subtable1 <- traits_table %>% filter(trait_type=="binary") %>% select(vars)
    subtable2 <- traits_table %>% filter(trait_type=="quantitative") %>% select(vars)
  }
  
  for (j in 1:5) {
    var_measurement <- colnames(subtable1)[j]
    WRT1 <- wilcox.test(subtable1[[j]], subtable2[[j]], paired=FALSE)
    p_value <- WRT1$p.value
    p_values_WRT <- p_values_WRT %>% add_row(
      var_measurement = var_measurement,
      var_comparison = var_comparison,
      unadj_p_value = p_value,
      adj_p_value = NA
    )
  }
  # Uses False Discovery Rate to adjust p-values. Adjusts within 5x1 plot
  adj_p_values_WRT <- p.adjust(p_values_WRT$unadj_p_value[(5*i-(5-1)):(5*i)],"fdr")
  p_values_WRT$adj_p_value[(5*i-(5-1)):(5*i)] <- adj_p_values_WRT
}

## Dual Density Plot function ####
dual_density <- function(data, mapping, the_var_comparison, the_var_measurement) {
  # extracts name of variable and xlim from scatterplot matrix
  x <- as.character(quo_get_expr(mapping[[1]]))
  xlims <- axis_lims[[x]]
  
  # gets adjusted p-values from Wilcoxon Ranked Test already done
  if (the_var_comparison=="group") {col_var <- "lifestyle"}
  else if (the_var_comparison=="type") {col_var <- "trait_type"}
  
  adj_p_value <- (p_values_WRT %>%
                    filter(var_measurement==the_var_measurement,
                           var_comparison==the_var_comparison))$adj_p_value
  
  # converts p-value to text version
  p_text_list <- p_value_to_text(adj_p_value)
  text <- paste0("Adj P = ",p_text_list[[1]],p_text_list[[2]])
  
  # Adds density plots
  p <- ggplot(data=data, mapping=aes(x=!!as.name(x) )) +
    geom_density(mapping=aes(fill=!!as.name(col_var)),alpha=0.5,size=0.5*sf) +
    xlim(xlims) +
    theme_light()
  
  # Adjusts legend to match the data
  if (the_var_comparison == "group") {
    p <- p +
      labs(fill="Trait Group") +
      scale_fill_manual(labels=c("Lifestyle","Other"),
                        breaks=c(TRUE, FALSE),
                        values = c("TRUE"="dodgerblue1", "FALSE"="gray20"))
  } else if (the_var_comparison == "type") {
    p <- p +
      labs(fill="Trait Type") +
      scale_fill_manual(labels=c("Binary","Quantitative"), 
                        breaks=c("binary", "quantitative"),
                        values = c("binary"="gray70", "quantitative"="gray10"))
  }
  # Adds p-value to plot
  yrange <- layer_scales(p)$y$range$range
  yrange[2] <- yrange[2] * 1.15 # pads top to allow space for p-value
  p <- p +
    ylim(yrange) +
    geom_text(data=NULL, label=text, x=max(xlims), y=max(yrange), vjust=1, hjust=1,
              color=p_text_list[[3]], size = 4*sf)
  
  p
}
# Actually generates and saves dual density plots to system
ddplot_width <- 1200
ddplot_height <- 200
ddplot_textsize <- 20
for (var_comparison in c("group","type")) {
  density_plots <- list()
  for (i in 1:5) {
    var_measurement <- vars[i]
    
    density_plot <- dual_density(data=traits_table,
                                 mapping = aes(x=!!as.name(var_measurement)),
                                 var_comparison, var_measurement)
    
    density_plots[[i]] <- density_plot
  }
  
  p_5x1 <- ggmatrix(plots=density_plots,
           nrow=1,
           ncol=5,
           legend=1,
           xAxisLabels = column_labels) +
    theme(legend.position="bottom",
          axis.text.y = element_blank(),
          legend.key.size = unit(1,"cm"),
          legend.text = element_text(size = ddplot_textsize*sf),
          text = element_text(size = ddplot_textsize*sf),
          axis.text.x = element_text(size=(ddplot_textsize*0.5)*sf))
  
  loc_out <- paste0(dir_out,"dual_density_plot_",var_comparison,".png")
  png(loc_out, width = ddplot_width*sf, height = ddplot_height*sf)
  print(p_5x1)
  dev.off()
  
  print(paste("Saved dual density plots for",var_comparison))
}
