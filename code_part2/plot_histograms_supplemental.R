#Generate overlap histogram 
rm(list = ls())
dev.off()

#Unload all packages 
library(pacman)
p_unload(all)

#Loading libraries
library(tidyverse)
library(rio)
library(data.table)
library(ggplot2)
library(igraph)

# sets working directory
setwd("./")

#Location of the traits table 
loc_table <- "../generated_data/traits_table.txt" 

# reads traits table
traits_table <- as.data.frame(fread(loc_table))

#Filter out problematic binary traits from traits_table
remove <- c("Malignant neoplasm of testis", 
            "Cancer of bladder", 
            "Cancer of brain", 
            "Thyroid cancer", 
            "Polycythemia vera", 
            "Nontoxic multinodular goiter", 
            "Thyrotoxicosis with or without goiter", 
            "Type 1 diabetes", 
            "Diabetic retinopathy", 
            "Hypoglycemia", 
            "Gout", 
            "Disorders of iron metabolism", 
            "Disorders of bilirubin excretion", 
            "Congenital deficiency of other clotting factors (including factor VII)", 
            "Dementias", 
            "Alzheimer's disease", 
            "Multiple sclerosis", 
            "Retinal detachments and defects", 
            "Macular degeneration (senile) of retina NOS", 
            "Corneal dystrophy", 
            "Peripheral vascular disease, unspecified", 
            "Nasal polyps", 
            "Appendiceal conditions", 
            "Celiac disease", 
            "Other chronic nonalcoholic liver disease", 
            "Rhesus isoimmunization in pregnancy", 
            "Lupus (localized and systemic)", 
            "Psoriasis", 
            "Sarcoidosis", 
            "Rheumatoid arthritis", 
            "Ankylosing spondylitis", 
            "Polymyalgia Rheumatica", 
            "Ganglion and cyst of synovium, tendon, and bursa", 
            "Contracture of palmar fascia [Dupuytren's disease]")

traits_table <- traits_table[!(traits_table$description %in% remove),]

#Filter tibble to include prive_code, description, trait_type, group
traits_table <- traits_table %>% select(c(prive_code, description, trait_type, group))

#Revise the trait groups 
groups_consolidated <- list(
  "Diseases" = c("circulatory system","dermatologic","digestive",
                 "endocrine/metabolic","genitourinary","hematopoietic",
                 "musculoskeletal","neoplasms","neurological",
                 "psychiatric disorders","respiratory","sense organs",         
                 "symptoms"),
  "Biological measures" = c("biological measures"),
  "Lifestyle/psychological" = c("lifestyle and environment", "psychiatric disorders"),
  "Physical measures" = c("injuries & poisonings","physical measures","sex-specific factors")
)
for (i in 1:nrow(traits_table)) {
  for (group_consolidated in names(groups_consolidated)) {
    if (traits_table$group[i] %in% groups_consolidated[[group_consolidated]]) {
      traits_table$group_consolidated[i] <- group_consolidated
      break
    }
  }
}
rm(i, group_consolidated)

#Remove duplicate column 
traits_table$group <- traits_table$group_consolidated
traits_table <- traits_table[, 1:(ncol(traits_table)-1)]

#Load the table with top bins for each trait 
top_bins_loc <- "../generated_data/bin_overlap.csv" 
top_bins_table <- import(file=top_bins_loc, header = TRUE)

#Load trait names into a vector
traits <- top_bins_table$prive_code

#Filter down the traits vector using a column of the traits_table
filtered_traits <- traits_table$prive_code
traits <- traits[traits %in% filtered_traits]

#Filter down top_bins_table using traits vector
top_bins_table <- top_bins_table[top_bins_table$prive_code %in% traits,]

#Match order of traits_table with top_bins_traits
traits_table <- traits_table[match(traits, traits_table$prive_code),]

#Prepare top_bins_table for construction of similarity matrix
top_bins_table <- top_bins_table[, 3:ncol(top_bins_table)]

#Remove unnecessary values 
rm(filtered_traits, loc_table, top_bins_loc, remove, groups_consolidated)

#Creation of similarity matrix 
similarity_matrix <- data.frame(matrix(ncol=177, nrow=177))

#Fill similarity matrix
for (row in 1:nrow(top_bins_table)) {
  vector <- c(unlist(top_bins_table[row,]))
  vector <- vector[!is.na(vector)]
  for (row2 in 1:nrow(top_bins_table)) {
    vector2 <- c(unlist(top_bins_table[row2,]))
    vector2 <- vector2[!is.na(vector2)]
    sim <- length(intersect(vector2, vector))
    similarity_matrix[row, row2] <- sim
  }
}
rm(row, row2, sim, vector, vector2)

#Set the row and column names to the traits vector
row.names(similarity_matrix) <- traits
colnames(similarity_matrix) <- traits

#Section specific to the histogram 
#Empty vectors for overlap in trait_groups - Maybe just append to generate_network_graph script
all_vector <- c()
lifestyle_vector <- c()
biological_vector <- c()
disease_vector <- c()
physical_vector <- c()

#Iterate through similarity matrix and append to corresponding vectors
for (row in 1:nrow(similarity_matrix)) {
  trait <- rownames(similarity_matrix)[row]
  trait_row <- traits_table[(traits_table$prive_code == trait),]
  trait_group <- trait_row$group
  # print(trait)
  # print(trait_group)
  for (col in 1:ncol(similarity_matrix)) {
    if (row > col ) {
      trait2 <- colnames(similarity_matrix)[col]
      trait_col <- traits_table[(traits_table$prive_code == trait2),]
      trait2_group <- trait_col$group
      overlap <- similarity_matrix[row, col]
      all_vector <- c(all_vector, overlap)
      if (trait_group == "Biological measures" & trait2_group == "Biological measures") {
        biological_vector <- c(biological_vector, overlap)
      } else if (trait_group == "Diseases" & trait2_group == "Diseases") {
        disease_vector <- c(disease_vector, overlap)
      } else if (trait_group == "Physical measures" & trait2_group == "Physical measures") {
        physical_vector <- c(physical_vector, overlap)
      } else if (trait_group == "Lifestyle/psychological" & trait2_group == "Lifestyle/psychological") {
        lifestyle_vector <- c(lifestyle_vector, overlap)
      }
    }
  }
}
rm(col, row, trait, trait_group, trait2, trait2_group, overlap)

#Create variables for the mean and median 
mean_all <- mean(all_vector)
median_all <- median(all_vector)
mean_lifestyle <- mean(lifestyle_vector)
median_lifestyle <- median(lifestyle_vector)
mean_biological <- mean(biological_vector)
median_biological <- median(biological_vector)
mean_disease <- mean(disease_vector)
median_disease <- median(disease_vector)
mean_physical <- mean(physical_vector)
median_physical <- median(physical_vector)

#Generate dataframe from vectors
df <- data.frame(matrix(ncol=2, nrow=0))
makedf <- function(group, vectors) {
  vector_df <- data.frame(matrix(ncol=2, nrow=length(vectors)))
  vector_df[,1] <- group
  vector_df[,2] <- as.numeric(vectors)
  return(vector_df)
}

#Appending to dataframe
df <-rbind(df, makedf('Lifestyle/psychological', lifestyle_vector))
df <-rbind(df, makedf('Biological measures', biological_vector))
df <-rbind(df, makedf('Diseases', disease_vector))
df <-rbind(df, makedf('Physical measures', physical_vector))
colnames(df) <- c("trait_group", "overlap")

#Generation of new dataframes for each trait group
library(ggpubr)

df1 <- subset(df, trait_group == 'Biological measures')
plot1 <- ggplot(data=df1,aes(x=overlap)) + scale_x_continuous(name="", breaks=c(0, 20, 40, 60, 80, 100)) + xlab("Number of Overlapping Bins") + ylab("Count") +
  geom_histogram(fill = "#F8766D", alpha = 1.0, binwidth=1) + xlim(-1,100) + ggtitle("Biological measures") + theme(axis.text=element_text(size=10), axis.title=element_text(size=10), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(colour = "black", size=0.25, fill=NA)) + annotate("text",  x=Inf, y = Inf, label = paste("Mean = ", round(mean_biological,2)), vjust=4, hjust=1.5) + annotate("text",  x=Inf, y = Inf, label = "Max = 83", vjust=6, hjust=2)
#print(plot1)

df2 <- subset(df, trait_group == 'Diseases')
plot2 <- ggplot(data=df2,aes(x=overlap)) + scale_x_continuous(name="", breaks=c(0, 20, 40, 60, 80, 100)) + xlab("Number of Overlapping Bins") + ylab("Count") +
  geom_histogram(fill = "#A3A500", alpha = 1.0, binwidth=1) + xlim(-1,100) + ggtitle("Diseases") + theme(axis.text=element_text(size=10), axis.title=element_text(size=10), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(colour = "black", size=0.25, fill=NA)) + annotate("text",  x=Inf, y = Inf, label = paste("Mean = ", round(mean_disease,2)), vjust=4, hjust=1.5) + annotate("text",  x=Inf, y = Inf, label = "Max = 32", vjust=6, hjust=2)
#print(plot2)

df3 <- subset(df, trait_group == 'Lifestyle/psychological')
length(unique(df3[c("overlap")])[[1]])
plot3 <- ggplot(data=df3,aes(x=overlap)) + scale_x_continuous(name="", breaks=c(0, 20, 40, 60, 80, 100)) + xlab("Number of Overlapping Bins") + ylab("Count") +
  geom_histogram(fill = "#00BF7D", alpha = 1.0, binwidth=1) + xlim(-1,100) + ggtitle("Lifestyle/psychological") + theme(axis.text=element_text(size=10), axis.title=element_text(size=10), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(colour = "black", size=0.25, fill=NA)) + annotate("text",  x=Inf, y = Inf, label = paste("Mean = ", round(mean_lifestyle,2)), vjust=4, hjust=1.5) + annotate("text",  x=Inf, y = Inf, label = "Max = 10", vjust=6, hjust=2)
#print(plot3)

df4 <- subset(df, trait_group == 'Physical measures')
plot4 <- ggplot(data=df4,aes(x=overlap)) + scale_x_continuous(name="", breaks=c(0, 20, 40, 60, 80, 100)) + xlab("Number of Overlapping Bins") + ylab("Count") +
  geom_histogram(fill = "#00B0F6", alpha = 1.0, binwidth=1) + xlim(-1,100) + ggtitle("Physical measures") + theme(axis.text=element_text(size=10), axis.title=element_text(size=10), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(colour = "black", size=0.25, fill=NA)) + annotate("text",  x=Inf, y = Inf, label = paste("Mean = ", round(mean_physical,2)), vjust=4, hjust=1.5) + annotate("text",  x=Inf, y = Inf, label = "Max = 94", vjust=6, hjust=2)
#print(plot4)

#Arrange into 4 row plot
g <- ggarrange(plot1, plot2, plot3, plot4, ncol = 1, nrow=4)
print(g)

ggsave(file = "FigureS1.pdf", units = c("in"), width=5, height=7, dpi=300, g)
