# load libraries
library(tidyr)
library(purrr) # reduce

# folder
setwd("~/Documents/itc_utwente/frank_malaria_ghana/csv/")

# list and read in all csv
lst.csv <- list.files(path = "~/Documents/itc_utwente/frank_malaria_ghana/csv/",
                      pattern = glob2rx("*.csv"), full.names = TRUE)
dat.lst <- lapply(lst.csv, read.csv, header = TRUE, sep = "|")

# shrink names to only file names
names(dat.lst) <- basename(lst.csv)
names(dat.lst)
length(dat.lst)

# columns for min, max, sd and avr
min_col <- seq(14, 445, by = 4)
max_col <- seq(15, 445, by = 4)
avr_col <- seq(16, 445, by = 4)
sd_col <- seq(17, 445, by = 4)

# gather
for (i in 1:length(dat.lst)) {
  dat.lst[[i]] <- reshape(dat.lst[[i]], idvar = "cat", 
                          varying = list(min_col,max_col,avr_col,sd_col), 
                          v.names = c("min", "max","avr","sd"), 
                          direction = "long")
}

# check that all df have the same dimension
lapply(dat.lst, dim)

# edit table names to attach to colnames per table 
to_remove1 <- "GHA_distr_"
to_remove2 <- ".csv"
to_remove3 <- "_scaled"
col_names <- gsub(to_remove1, "", names(dat.lst))
col_names <- gsub(to_remove2, "", col_names)
col_names <- gsub(to_remove3, "", col_names)
col_names

rm(to_remove1,to_remove2,to_remove3)

# edit names and add a new ID to join
for (i in seq_along(dat.lst)) {
  # add preffix with var name
  dat.lst[[i]] <- setNames(dat.lst[[i]], paste0(col_names[i],"_",names(dat.lst[[i]])))
  # add IDs col to join
  dat.lst[[i]]$ID_new <- seq(1,dim(dat.lst[[i]])[1])
}

names(dat.lst[[1]])

# merge dfs in the list
merged_list_df <- reduce(dat.lst, merge, by = "ID_new", all = TRUE)
class(merged_list_df)
names(merged_list_df)

# clean
toremove <- c(21:33,38:51,56:69,308:321,326:339,344:357,362:375)
toremove2 <- c(33:46,51:64,69:82,87:100,105:118,123:136,141:154,159:172,177:190,195:208,
              213:226,231:244,249:262)
merged_list_df[toremove2] <- list(NULL)

# add year and month cols
merged_list_df$year <- rep(2009:2017, each=2592)
merged_list_df$month <- rep(01:12, each=216)
head(merged_list_df)

# export
write.csv(merged_list_df, file = "ghana_rs_2009_2017.csv", row.names = FALSE)
