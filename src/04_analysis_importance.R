#' ## Importance analysis
#' This script carries out an analysis on the importance of the
#' predictos used by the random forests

library(tidyverse)
library(randomForest)

#' The target data is in `BASE_PATH` and the `NUTS_LEVEL` sets the level
#' of spatial aggregation for the predictors (meteorological data from ERA-NUTS)

BASE_PATH <- "ts_prod/"
NUTS_LEVEL <- "NUTS0"

#' The script `get_file_list.R` loads the list of the target files
#' with a set of metadata for each of them
source("get_file_list.R")
file_list <- get_file_list()
print(head(file_list))

#' Read the errors computed by `02_compute_errors.R`
errors <- read_rds(sprintf("errors-%s.rds", NUTS_LEVEL))

#' Storing here the importance data
importance_data <- list()

for (i in seq(1, length(errors))) {
  
  #' Get the medatata for the i-th filename
  metadata <- file_list %>%
    filter(filename == errors[[i]]$filename)
  
  if (nrow(metadata) == 0) {
    warning("The error-data with index ", i, " is not in the filelist")
  } else {
    importance_data[[i]] <- importance(errors[[i]]$single_model) %>%
      as_tibble(rownames = "varname") %>%
      select(varname, `%IncMSE`) %>%
      separate(varname, into = c("varbasename", "areaname"), sep = "_") %>%
      group_by(varbasename) %>%
      summarise(`%IncMSE` = mean(`%IncMSE`)) %>%
      mutate(
        filename = metadata$filename,
        source = metadata$source,
        country = metadata$country,
        area_name = metadata$area_name
      )
  }
}

#' Plot the results
g  = ggplot(importance_data %>% bind_rows(), 
            aes(x = varbasename, y = `%IncMSE`)) + 
  geom_boxplot() + 
  facet_wrap(~source) +
  theme_light() +
  xlab('Variable name')
print(g)
