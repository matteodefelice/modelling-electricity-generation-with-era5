#' ## Hyper-parameter tuning
#' This script calculates for each model the best set of parameters
#' for the random forest

library(tidyverse)
library(feather)

#' The script `evaluate_rf.R` is a function performing a cross-validation
#' with a random forest and returning a set of performance measures
source("evaluate_rf.R")

#' Instead `get_file_list.R` loads the list of the target files
#' with a set of metadata for each of them
source("get_file_list.R")
file_list <- get_file_list()
print(head(file_list))

#' The target data is in `BASE_PATH` and the `NUTS_LEVEL` sets the level
#' of spatial aggregation for the predictors (meteorological data from ERA-NUTS)

BASE_PATH <- "ts_prod/"
NUTS_LEVEL <- "NUTS0"

#' `res` will contain all the hyper-parameters
res <- NULL

#' For each target file the algorithm will test a set of hyper-parameters calculating
#' the error

for (index in seq(1, nrow(file_list))) {
  region <- file_list$country[index]
  message(region)

  #' Load the meteorological predictors
  e5 <- sprintf("ERA5-NUTS-2015-2018/%s-%s.feather", region, NUTS_LEVEL) %>%
    read_feather()
  #' Load the target data
  ts_prod <- paste0(BASE_PATH, file_list$filename[index]) %>%
    read_feather()

  #' Use for the target column in `ts_prod` the name `Generation`
  if ("Value" %in% colnames(ts_prod)) {
    ts_prod <- ts_prod %>%
      rename(Generation = Value)
  }

  #' In the modelling omit all the target values where the generation
  #' is below the 10th percentile. 
  THRES <- quantile(ts_prod$Generation, 0.1, na.rm = TRUE)

  full <- inner_join(e5, ts_prod,
    by = c("time" = "Datetime")
  ) %>%
    select(-contains("Type")) %>%
    select(-contains("Name")) %>%
    select(-contains("Area")) %>%
    select(-contains("region")) %>%
    filter(!is.na(Generation)) %>%
    filter(Generation > THRES) %>%
    select(-time) %>%
    select(-starts_with("CS_")) %>%
    select(-starts_with("ssrdc_")) %>%
    rename(y = Generation)
  
  print(head(full))

  #' Set the list of the hyper-parameters to explore. See the
  #' the randomForest documentation for more information
  if (nrow(full) > 0) {
    NT <- c(50, 100, 200)
    MNODES <- 100
    MTRY <- unique(
      round(
        ncol(full) *
          c(0.1, 0.2, 0.33, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9)
      )
    )
    #' For each combination evaluate the randomForest (without cross-validation)
    #' thus with `K` set to 1 and append the output to the results 
    for (nt in NT) {
      for (mnodes in MNODES) {
        for (mtry in MTRY) {
          e <- evaluate_rf(full,
            K = 1,
            nt = nt,
            mnodes = mnodes,
            mtry = mtry,
            assess_importance = FALSE
          )

          to_append <- tibble(
            filename = file_list$filename[index],
            nt = nt, mnodes = mnodes,
            mtry = mtry,
            oob_cor = e$single$cor,
            oob_nmae = e$single$mae / mean(e$target)
          )
          
          if (is.null(res)) {
            res <- to_append
          } else {
            res <- rbind(res, to_append)
          }
        }
      }
    }
  }
}
print(head(res))
write_rds(res, sprintf("hyperparams-%s.rds", NUTS_LEVEL))
