# print_tables.R

# This script produces the tables found in the publication and supplemental

### Libraries and directories ####
library(tidyverse)
library(webshot)
library(gt)
library(data.table)

# sets working directory
setwd("./")

# sets the location of the traits table
loc_table <- "../generated_data/traits_table.txt"
# sets directory of outputted figures
dir_out <- "../generated_figures/"

### Code ####

gt_theme <- function(data) {
  
  tab_options(
    data = data,
    table.font.name = "Helvetica"
  ) %>%
    cols_align(
      align = "center",
      columns = everything()
    )
}

#### Makes big traits table ####

# reads traits table
traits_table <- as_tibble(fread(loc_table))
vars <- c("ldpred2_h2","cMperMb","gini_United","pcor_United","portability_index", "f_stat")
rounding_decimals <- 3

# makes list of low prevalence binary traits to exclude from table
low_prevalence <- (traits_table %>% filter(prevalence < 0.01))$description

# defines Table S1
big_table <- traits_table %>%
  filter(!(description %in% low_prevalence)) %>%
  select(description, trait_type, group_consolidated, all_of(vars)) %>%
  mutate(trait_type = ifelse(trait_type=="binary","Binary","Quantitative"),
         description = ifelse(description %in% low_prevalence, paste0(description,"*"),description),
         f_stat = log10(f_stat),
         portability_index = ifelse(portability_index>0,0,portability_index)) %>%
  group_by(trait_type) %>%
  arrange(group_consolidated, description)

# converts Table S1 into a GT table
big_table_gt <- gt(big_table) %>%
  gt_theme() %>%
  summary_rows(
    columns = vars,
    groups = TRUE,
    fns = list("Mean" = ~mean(.)),
    formatter = fmt_number,
    decimals = rounding_decimals
  ) %>%
  cols_label(
    description = "Trait",
    group_consolidated = "Trait Group",
    ldpred2_h2 = md("h<sup>2</sup><sub>SNP</sup>"),
    cMperMb = "R",
    gini_United = md("G<sub>100,UK</sub>"),
    pcor_United = md("&rho;<sub>UK</sub>"),
    portability_index = "m",
    f_stat = md("D")
  ) %>%
  fmt_number(
    columns = vars[vars !="portability_index"],
    suffixing = F,
    decimals = rounding_decimals
  ) %>%
  fmt_number(
    columns = portability_index,
    suffixing = F,
    decimals = 5
  ) %>%
  cols_align(
    align = "left",
    columns = c("description")
  ) %>%
  tab_header(
    title = paste("The Six Summary Statistics for", nrow(big_table),"Traits"),
    subtitle = "Full table provided in Github repository"
  )

# saves Table S1 to system
big_table_gt
gtsave(big_table_gt, "table_big_table.png", dir_out, vwidth = 1000, zoom = 1, cliprect=c(0,0,1000,6000))
# for some reason, text gets cutoff when printed as a PDF
big_table_gt <- big_table_gt %>% tab_options(table.font.size = "90%") 
gtsave(big_table_gt, "table_big_table.pdf", dir_out, vwidth = 1000, zoom = 1, cliprect=c(0,0,1000,6000))


#### Makes High and Low Gini Table ####
n_show <- 10 # shows top n_show highest and top n_show lowest

# temporary table with just the gini, trait, and rank 
temp <- traits_table %>%
  filter(prevalence > 0.01 | trait_type=="quantitative") %>%
  arrange(gini_United) %>%
  mutate(gini_United = as.character(formatC(gini_United,rounding_decimals,format="f")),
         rank = row_number()) %>%
  select(rank, description,gini_United)

# total number of traits (should be 177)
N_total <- nrow(temp)

# makes Table 1
table1 <- temp %>%
  filter(rank <= n_show) %>%
  add_row(
    rank = 0, description = "...",
    gini_United = ""
  ) %>%
  add_row(
    temp %>% filter(row_number() > (N_total - n_show))
  ) %>%
  mutate(rank = ifelse(rank==0,"",as.character(rank)))

# converts Table 1 into a GT table
table1gt <- gt(table1) %>%
  gt_theme() %>%
  cols_label(
    rank = "#",
    description = "Trait",
    gini_United = md("G<sub>100,UK</sub>")
  ) %>%
  cols_align(
    align = "left",
    columns = c("description")
  ) %>%
  tab_header(
    title = paste0(n_show," Lowest and ",n_show," Highest Gini Traits")
  )

# saves Table 1 to system
table1gt
gtsave(table1gt, paste0("table1_ALL",n_show,".png"), dir_out, vwidth = 2160, vheight=1620)
print(paste("Made gini table for",the_trait_type,"traits"))


#### Makes High and Low Divergence Table ####
n_show <- 10 # shows top n_show highest and top n_show lowest

# temporary table with just the divergence, trait, and rank
temp <- traits_table %>%
  filter(prevalence > 0.01 | trait_type=="quantitative") %>%
  mutate(f_stat = log10(f_stat)) %>%
  arrange(f_stat) %>%
  mutate(f_stat = as.character(formatC(f_stat,rounding_decimals,format="f")),
         rank = row_number()) %>%
  select(rank, description, f_stat)

# total number of traits (should be 177)
N_total <- nrow(temp)

# makes Table 2
table2 <- temp %>%
  filter(rank <= n_show) %>%
  add_row(
    rank = 0, description = "...",
    f_stat = ""
  ) %>%
  add_row(
    temp %>% filter(row_number() > (N_total - n_show))
  ) %>%
  mutate(rank = ifelse(rank==0,"",as.character(rank)))

# converts Table 2 into a GT table
table2gt <- gt(table2) %>%
  gt_theme() %>%
  cols_label(
    rank = "#",
    description = "Trait",
    f_stat = md("Divergence (D)")
  ) %>%
  cols_align(
    align = "left",
    columns = c("description")
  ) %>%
  tab_header(
    title = paste0(n_show," Lowest and ",n_show," Highest Divergence Traits")
  )

# saves Table 2 to system
table2gt
gtsave(table2gt, paste0("table2_ALL",n_show,".png"), dir_out, vwidth = 1160, vheight=1620)
print(paste("Made divergence table"))
