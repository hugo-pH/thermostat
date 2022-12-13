Home thermostat
================

This is a repository to process and analyze data from my Netatmo smart thermostat. The goal is to build a pipeline that reads the export data from the Netatmo website and adds it to a database. In addition, weather data is obtained from [vissualcrossing](visualcrossing.com/) using their API, and subsequently stored in the database.

After downloading files from the Netatmo website, the process of reading the export files, downloading the weather data, and populating the database is automated with a [targets](https://docs.ropensci.org/targets/) pipeline.

## Contents

- [Project structure](#project-structure)
- [Input data](#input-data)
- [Database](#database)
- [Pipeline](#pipeline)
- [Dependencies](#dependencies)


## Project structure

This project contains the following directories:

- `data/`: 

  - `input/`: contains the input files downloaded fron the Netatmo website
  - `database/`: contains the SQLite database file
  
- `R/`: contains all functions
- `reports/`: contains reports to visualize the data
- `_targets`: directory created by the [targets](https://docs.ropensci.org/targets/) package required to run the pipeline
- `renv`: directory created by the [renv](https://rstudio.github.io/renv/articles/renv.html) package required to manage project dependencies

## Input data

The input data is the Netatmo export files that can downloaded from the user area. The pipeline is intended for the .csv export files with the "Heating ON time" option. These files contain the thermostat readings performed every ~10 minutes. Apart from timestamps, the files contain the recorded temperature, the setpoint and the time (in seconds) the boiler was on or off.

## Database

The SQLite database contains three tables, thermostat, weather and a datehour. It can be created by running the function `create_db()` in the `R/create_db.R` file.

```
root.dir <- here::here()
source(file.path(root.dir, "R", "create_db.R"))
db.path <- file.path(root.dir, "data", "database", "thermostat_db.sqlite")
# Note the `data/database` directory is not present in this repository, 
# so it needs to be created before creating the database:
dir.create(file.path(root.dir, "data", "database"))
create_db(db.path)
```

## Pipeline

Once the database has been created, it can be populated by running the [targets](https://docs.ropensci.org/targets/) pipeline. New thermostat export files should be stored in `data/input` (or the path should be modified in the `_targets.R` file). In addition, the API key from [vissualcrossing](visualcrossing.com/) should be specified in `_targets.R` (`api.key`). To run the pipeline:

```
targets::tar_make()
```

This will automatically run the [quarto](https://quarto.org/) document in `reports/monthly_usage` and update the html report in the same directory.


## Dependencies

[`renv`](https://rstudio.github.io/renv/articles/renv.html) files are provided to facilitate dependency management. We include the `.Rprofile` file so when cloning the repository and opening the project, `renv` should be automatically downloaded and installed and project dependencies can be restore with `renv::restore()`. See [this resource](https://rstudio.github.io/renv/articles/collaborating.html) for further details.
