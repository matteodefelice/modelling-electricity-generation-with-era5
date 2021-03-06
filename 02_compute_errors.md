## Cross-validation errors
This script calculates the error in cross-validation using the parameters
defined by the hyper-parameter tuning



```r
library(tidyverse)
library(feather)
```

The script `evaluate_rf.R` is a function performing a cross-validation
with a random forest and returning a set of performance measures


```r
source("evaluate_rf.R")
```

Instead `get_file_list.R` loads the list of the target files
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

The target data is in `BASE_PATH` and the `NUTS_LEVEL` sets the level
of spatial aggregation for the predictors (meteorological data from ERA-NUTS)


```r
BASE_PATH <- "ts_prod/"
NUTS_LEVEL <- "NUTS0"
```

Load the errors for hyper-parameters calculated in the previous step


```r
hyperparams <- read_rds(sprintf("hyperparams-%s.rds", NUTS_LEVEL))
```

Select the parameters with the lowest normalised mean absolute error (NMAE)
To give priority to the "simplest" models the error has been rounded to 3 digits
and then a small delta based on the number of trees (`nt`) and the number of
variables used for splitting (`mtry`)


```r
selected <- hyperparams %>%
  mutate(rounded_nmae = round(oob_nmae, digits = 3) + nt * 1e-5 + mtry * 1e-7) %>%
  group_by(filename) %>%
  top_n(1, -rounded_nmae) %>%
  inner_join(file_list)
```

```
## Joining, by = "filename"
```

```r
print(head(selected))
```

```
## # A tibble: 6 x 16
## # Groups:   filename [6]
##   filename    nt mnodes  mtry oob_cor oob_nmae rounded_nmae area_name
##   <chr>    <dbl>  <dbl> <dbl>   <dbl>    <dbl>        <dbl> <chr>    
## 1 AT_ror.…    50    100     5   0.719    0.165        0.166 AT       
## 2 AT_sola…   100    100     5   0.924    0.247        0.248 AT       
## 3 AT_wind…    50    100     5   0.806    0.392        0.393 AT       
## 4 BE_sola…   100    100     6   0.898    0.318        0.319 BE       
## 5 BG_ror.…    50    100     6   0.855    0.186        0.187 BG       
## 6 BG_sola…   100    100     5   0.898    0.276        0.277 BG       
## # … with 8 more variables: country <chr>, source <chr>, active <dbl>,
## #   max <dbl>, q95 <dbl>, median <dbl>, avg <dbl>, nas <int>
```

Save the results in this list


```r
res <- list()
```

For each target file the algorithm will test a set of hyper-parameters calculating
the error


```r
for (index in seq(1, nrow(selected))) {
  
  #' This is the target country
  region <- file_list$country[index]
  
  #' Load the meteorological predictors
  e5 <- sprintf("ERA5-NUTS-2015-2018/%s-%s.feather", region, NUTS_LEVEL) %>%
    read_feather()
  
  #' Load the target data
  ts_prod <- paste0(BASE_PATH, file_list$filename[index]) %>%
    read_feather()
  
  message("Evaluating ", file_list$filename[index])
  
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

  #' Calibrate a random forest on the `full` data frame and return the 
  #' error computed with a 20-fold cross-validation. The parameters are
  #' the ones selected at the beginning of the script 
  e <- evaluate_rf(full,
    K = 20,
    nt = selected$nt[index],
    mnodes = selected$mnodes[index],
    mtry = selected$mtry[index]
  )
  
  #' Return a data frame containing the filename containing the target data, 
  #' a random forest model calibrated before the cross-validation, the correlation
  #' and the NMAE computed out-of-bag, the NMAE in cross-validation and the
  #' cross-validation output (yhat). 
  res[[index]] <- list(
    filename = file_list$filename[index],
    single_model = e$single$single_model,
    oob_cor = e$single$cor,
    oob_nmae = e$single$mae / mean(e$target),
    cv_nmae = map_dbl(e$cv, ~ .$cv_mae) / mean(e$target),
    cv_out = map(e$cv, ~ .$yhat) %>% unlist(),
    target = e$target
  )
  
}
```


```r
write_rds(res, sprintf("errors-%s.rds", NUTS_LEVEL))
```

