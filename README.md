# Modelling renewable electricity generation in Europe with Copernicus ERA5 reanalysis

This repository contains a set of R scripts and the data illustrating the possibility to model hourly electricity generation from renewable sources using the latest climate reanalysis from the Copernicus Climate Change Service (C3S). This work was supposed to be part of a scientific paper but then I have opted for a public repository. 

## Structure

This repository contains all the code and the data to run from scratch the analysis. The main folder contains all the markdown, while in `src` there is all the R files and the data.

## Data sources

This work is based on two datasets:

1.  [ERA-NUTS](https://zenodo.org/record/2650191#.XYkN9JMzY3E): time-series based on ERA5 reanalysis for all the European regions using the NUTS 2016 classification. The original data has been split in single feather files in the folder `src/ERA5-NUTS-2015-2018`. 
2.  Electricity generation data: the data is coming from the [ENTSO-E Transparency platform](https://transparency.entsoe.eu/dashboard/show) for run-of-river hydro-power (`Hydro Run-of-river and poundage`) and from [Open Power System Data time-series](https://data.open-power-system-data.org/time_series/2018-06-30) for wind and solar. The data has been split for country and generation type in feather files in the folder `src/ts_prod`. 

## Requirements

To run the code you need:
* R
* some famous packages like the `tidyverse` meta-package, `lubridate`, `randomForest` and `feather`
* the package [`DALEX`](https://modeloriented.github.io/DALEX/), possibly a recent version (I have used the 0.4.4)

## References
This code is inspired by the work done during the [C3S ECEM project](https://climate.copernicus.eu/european-climate-energy-mixes) and described in [this paper by Troccoli et al.](https://www.adv-sci-res.net/15/191/2018/).
