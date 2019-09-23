#' ## Plotting the errors
#' This script reads the errors computed by `02_compute_errors.R` and prepare
#' a plot.
library(tidyverse)


#' The target data is in `BASE_PATH` and the `NUTS_LEVEL` sets the level
#' of spatial aggregation for the predictors (meteorological data from ERA-NUTS)

BASE_PATH <- "ts_prod/"
NUTS_LEVEL <- "NUTS0"

#' The script `get_file_list.R` loads the list of the target files
#' with a set of metadata for each of them
source("get_file_list.R")
file_list <- get_file_list()
print(head(file_list))

#' Read the errors
errors <- read_rds(sprintf("errors-%s.rds", NUTS_LEVEL))

#' A list containing all the data needed for the plot extracted by
#' the list with errors
#' 
data_for_plot <- list()
for (i in seq(1, length(errors))) {
  #' Get the medatata for the i-th filename
  metadata <- file_list %>%
    filter(filename == errors[[i]]$filename)
  if (nrow(metadata) == 0) {
    warning("The error-data with index ", i, " is not in the filelist")
  } else {
    data_for_plot[[i]] <- tibble(
      area_name = metadata$area_name,
      source = metadata$source,
      nmae = errors[[i]]$cv_nmae,
      k = seq(1, length(errors[[i]]$cv_nmae))
    )
  }
}

## SAVE RDS --------------------------------------------------------
#' Save the data for the plot as a RDS
write_rds(data_for_plot, sprintf("errors-summary-%s.rds", NUTS_LEVEL))

## PLOT ------------------------------------------------------------
#' Prepare the ggplot plot
g <- ggplot(data_for_plot %>% bind_rows()) +
  geom_point(aes(x = area_name, y = nmae), alpha = 0.3) +
  geom_point(
    data = data_for_plot %>%
      bind_rows() %>%
      group_by(area_name, source) %>%
      summarise(avg_nmae = mean(nmae)),
    aes(x = area_name, y = avg_nmae),
    color = "red", size = 2
  ) +
  scale_y_continuous(breaks = seq(0, 2, 0.1)) +
  facet_wrap(~source) +
  theme_light() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
ggsave(filename = sprintf("errors-summary-%s.png", NUTS_LEVEL), width = 9, height = 4)

print(g)