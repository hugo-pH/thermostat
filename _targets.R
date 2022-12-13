# Created by use_targets().

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes)
# Set target options:
tar_option_set(
  packages = c("tibble", "quarto"), # packages that your targets need to run
  format = "rds" # default storage format
  # Set other options as needed.
)

# Run the R scripts in the R/ folder with your custom functions:
tar_source()

list(
  # Define DB file path
  tar_target(
    name = db.path,
    command = file.path(here::here(), "data", "database", "thermostat_db.sqlite")
  ),
  # Define path to input directory
  tar_target(
    name = input.dir,
    command = file.path(here::here(), "data", "input")
  ),
  # Define Visual Crossing API key
  tar_target(
    name = api.key,
    command = ""
  ),
  # Populate database
  tar_target(
    name = populate.db,
    command = populate_db(dir = input.dir, db = db.path, api.key = api.key, return_path = TRUE)
  ),
  tar_quarto(
    monthly.report, 
    file.path(here::here(), "reports", "monthly_usage", "monthly_usage.qmd"),
    execute_params = list(db_file = populate.db)
    )
)
