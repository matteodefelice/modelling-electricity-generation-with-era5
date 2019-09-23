

```r
options(warn=-1)
```

## The effect of each input variable
This script takes advantage of the powerful functions provided by the
`DALEX` package to identify the "effect" of each variable used as predictor
on the output of the random forest. The homepage of the package is
[here](https://modeloriented.github.io/DALEX/) and the philosophy behind
it is explained in [this book](https://pbiecek.github.io/PM_VEE/).


```r
library(tidyverse)
library(randomForest)
library(DALEX)
```

`NUTS_LEVEL` sets the level
of spatial aggregation for the predictors (meteorological data from ERA-NUTS)


```r
NUTS_LEVEL <- "NUTS0"
```

The script `get_file_list.R` loads the list of the target files
with a set of metadata for each of them


```r
source("get_file_list.R")
file_list <- get_file_list()
```

```
## Parsed with column specification:
## cols(
##   area_name = col_character(),
##   country = col_character(),
##   source = col_character(),
##   active = col_double(),
##   filename = col_character()
## )
```

```
## Joining, by = c("area_name", "country", "source", "active", "filename")
```

```r
print(head(file_list))
```

```
## # A tibble: 6 x 10
##   area_name country source  active filename    max   q95 median   avg   nas
##   <chr>     <chr>   <chr>    <dbl> <chr>     <dbl> <dbl>  <dbl> <dbl> <int>
## 1 AT        AT      ror          1 AT_ror.… 11419. 4604  2.75e3 2846.     0
## 2 AT        AT      solar        1 AT_sola…   886   468  1.30e1  115.     0
## 3 AT        AT      wind_o…      1 AT_wind…  2662  1527  2.60e2  439.     0
## 4 BE        BE      solar        1 BE_sola…  2620. 1595. 5.47e0  335.     0
## 5 BG        BG      ror          1 BG_ror.…   367   333  1.44e2  167.     0
## 6 BG        BG      solar        1 BG_sola…   856   658  3.00e0  150.     0
```

Read the errors computed by `02_compute_errors.R`


```r
errors <- read_rds(sprintf("errors-%s.rds", NUTS_LEVEL))
```

Here saving all the responses


```r
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
```

```
##   _vname_      _label_  _x_   _yhat_ _ids_ area_name source
## 1      ro randomForest 1.76 2141.611     0        AT    ror
## 2      ro randomForest 2.26 2285.572     0        AT    ror
## 3      ro randomForest 2.62 2510.178     0        AT    ror
## 4      ro randomForest 2.87 2473.929     0        AT    ror
## 5      ro randomForest 3.03 2644.007     0        AT    ror
## 6      ro randomForest 3.15 2649.496     0        AT    ror
```

Save the results


```r
write_rds(data_responses, sprintf("responses-%s.rds", NUTS_LEVEL))
```

