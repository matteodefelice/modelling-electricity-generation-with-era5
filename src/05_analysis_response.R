options(warn=-1)
#' ## The effect of each input variable
#' This script takes advantage of the powerful functions provided by the
#' `DALEX` package to identify the "effect" of each variable used as predictor
#' on the output of the random forest. The homepage of the package is
#' [here](https://modeloriented.github.io/DALEX/) and the philosophy behind
#' it is explained in [this book](https://pbiecek.github.io/PM_VEE/).

library(tidyverse)
library(randomForest)
library(DALEX)

#' `NUTS_LEVEL` sets the level
#' of spatial aggregation for the predictors (meteorological data from ERA-NUTS)

NUTS_LEVEL <- "NUTS0"

#' The script `get_file_list.R` loads the list of the target files
#' with a set of metadata for each of them
source("get_file_list.R")
file_list <- get_file_list()
print(head(file_list))

#' Read the errors computed by `02_compute_errors.R`
errors <- read_rds(sprintf("errors-%s.rds", NUTS_LEVEL))

#' Here saving all the responses
data_responses <- list()

for (i in seq(1, length(errors))) {
  
  #' Get the medatata for the i-th filename
  metadata <- file_list %>%
    dplyr::filter(filename == errors[[i]]$filename)
  
  if (nrow(metadata) == 0) {
    warning("The error-data with index ", i, " is not in the filelist")
  } else {
    #' Create an `explainer`, in other words a representation of a model,
    #' in this case a random forest
    expl <- DALEX::explain(errors[[i]]$single_model)
    
    #' Now for each predictor used in the random forest model we can calculate
    #' the Partial Dependency Profile. In this way we can see how the target
    #' variable changes with the single predictor. We use 31 points for the profile
    data_responses[[i]] <- lapply(
      names(errors[[i]]$single_model$forest$xlevels),
      function(x) {
        return(
          ingredients::partial_dependency(
            expl, 
            variables = x, 
            grid_points = 31
          )
        )
      }
    ) %>%
      bind_rows() %>%
      mutate(
        area_name = metadata$area_name,
        source = metadata$source
      )
  }
}

print(head(data_responses[[1]]))

#' Save the results
write_rds(data_responses, sprintf("responses-%s.rds", NUTS_LEVEL))
