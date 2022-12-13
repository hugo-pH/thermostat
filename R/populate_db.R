#' Check if a table exists in a database
#'
#' @param table The table name
#' @param db A SQLite database file
#'
#' @return If the table exists, nothing happens. If it does not exist, execution is aborted 
#' and a error message is returned
check_table_exist <- function(table, db){
  # connect to db
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), db)
  
  if(DBI::dbExistsTable(thermostat_db, table) == F){
    bullets <- c(
      "The provided database does not contain the {table} table",
      "Please, provide a database file with the required schema"
    )
    cli::cli_abort(bullets)
  }
  DBI::dbDisconnect(thermostat_db)
}

#' Populate the thermostat (and datehour) tables
#'
#' @param path Path to a netatmo thermostat export file
#' @param db A SQLite database file
#'
#' @return Does not return any object
populate_thermostat_tb <- function(path = NULL, db){
  # read netatmo export file
  thermostat <- read_netatmo_export(path) |> 
    dplyr::mutate(
      datehour = as.character(lubridate::floor_date(datetime, "hour")),
    )
  # check if database file exist
  if(file.exists(db) == FALSE){
    bullets <- c(
      "The provided database file does not exist",
      "Please, provide a correct database file"
    )
    cli::cli_abort(bullets)
  }
  # connect to db
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), db)
  
  # check if the provided database contains the tables
  tables <- list("datehour", "thermostat")
  purrr::walk(tables, check_table_exist, db = db)
  
  # date_hour_db_table <- DBI::dbReadTable(thermostat_db, "datehour")
  datehour_db_table <- dplyr::tbl(thermostat_db, "datehour") |> 
    dplyr::collect()
  
  date_hour_records_in_db <- datehour_db_table |> 
    dplyr::pull(datehour)
  
  thermostat_new_records <- thermostat |> 
    dplyr::filter(!datehour %in% date_hour_records_in_db)
  
  # Add those records not present in the database
  # First populate the datehour table
  new_date_hours <- thermostat_new_records |> 
    dplyr::mutate(
      year = lubridate::year(datehour),
      month = lubridate::month(datehour),
      day = lubridate::day(datehour),
      hour = lubridate::hour(datehour)
    ) |> 
    dplyr::distinct(datehour, year, month, day, hour)
  
  if(nrow(new_date_hours) == 0){
    print("No new records to be added.")
  }else{
    
    insert_datehours <- DBI::dbWriteTable(thermostat_db, "datehour", new_date_hours, append = T)
    
    if (insert_datehours) {
      print(glue::glue("Added {nrow(new_date_hours)} records to datahour table."))
    }
    
    # Then get the new datehour_ids
    datehour_db_table <- dplyr::tbl(thermostat_db, "datehour") |> 
      dplyr::collect()
    
    datehour_ids <- new_date_hours |> 
      dplyr::left_join(
        datehour_db_table,
        by = c("datehour", "year", "month", "day", "hour")
        
      ) |> 
      dplyr::select(datehour, datehour_id)
    
    new_theremostat <- thermostat_new_records |> 
      dplyr::right_join(datehour_ids, by = "datehour") |> 
      dplyr::select(-datehour) |> 
      dplyr::rename(thermostat_id = timestamp) |> 
      dplyr::mutate(datetime = as.character(datetime))
    
    insert_thermostat <- DBI::dbWriteTable(thermostat_db, "thermostat", new_theremostat, append = T) 
    
    if(insert_thermostat){
      print(glue::glue("Added {nrow(new_theremostat)} records to thermostat table."))
    }
  }
  DBI::dbDisconnect(thermostat_db)
}

#' Get hourly weather data from Visual Crossing for a specific day
#'
#' @param date A date object (YYYY-MM-DD)
#' @param lat Latitude
#' @param long Latitude
#' @param api.key The API key for Visual Crossing service
#'
#' @return a tibble
get_weather_data_vc <- function(date, lat, long, api.key){
  # url for visualcrossing API
  url <- "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/Amsterdam/2022-11-23/2022-11-25?unitGroup=metric&include=hours&key=6F4HFLENLB7KXLQJSHXPK9ZCR&contentType=csv"
  base.url <- "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/"
  end.url <- glue::glue("?unitGroup=metric&include=hours&key={api.key}&contentType=csv")
  url <- glue::glue("{base.url}{lat}%2C%20{long}/{date}/{date}{end.url}")
  resp <- httr::GET(url=url)
  
  # if
  if(resp$status_code == 429){
    bullets <- c(
      "The maximum number of queries on Visual Crossing has been reached."
    )
    cli::cli_abort(bullets)
    
  }
  httr::content(resp, encoding = "UTF-8") |> 
      readr::read_csv(
        col_types = readr::cols(
          name = readr::col_character(),
          datetime = readr::col_datetime(format = ""),
          temp = readr::col_double(),
          feelslike = readr::col_double(),
          dew = readr::col_double(),
          humidity = readr::col_double(),
          precip = readr::col_double(),
          precipprob = readr::col_double(),
          preciptype = readr::col_character(),
          snow = readr::col_double(),
          snowdepth = readr::col_double(),
          windgust = readr::col_double(),
          windspeed = readr::col_double(),
          winddir = readr::col_double(),
          sealevelpressure = readr::col_double(),
          cloudcover = readr::col_double(),
          visibility = readr::col_double(),
          solarradiation = readr::col_double(),
          solarenergy = readr::col_double(),
          uvindex = readr::col_double(),
          severerisk = readr::col_logical(),
          conditions = readr::col_character(),
          icon = readr::col_character(),
          stations = readr::col_character()
        ),
        show_col_types = FALSE
      ) |> 
      janitor::clean_names() |> 
      dplyr::rename(temperature = temp) 
}


#' Add weather records for a day into the weather database table
#'
#' @param date A date object (YYYY-MM-DD)
#' @param lat Latitude
#' @param long Latitude
#' @param db A SQLite database file
#' @param api.key The API key for Visual Crossing service
#' 
#' @return Does not return any object
add_one_weather_record <- function(date, lat, long, db, api.key){
    
  if(file.exists(db) == FALSE){
    bullets <- c(
      "The provided database file does not exist",
      "Please, provide a correct database file"
    )
    cli::cli_abort(bullets)
  }

  # check if the provided database contains the tables
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), db)
  tables <- list("datehour", "weather")
  purrr::walk(tables, check_table_exist, db = db)
  # disconnect from database to avoid leaving connection open if 
  # retrieving weather data fails
  DBI::dbDisconnect(thermostat_db)
  
  data <- get_weather_data_vc(date, lat, long, api.key = api.key)
  
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), db)
  # get the datehour records 
  datehour_db_table <- dplyr::tbl(thermostat_db, "datehour")
  
  new_weather_data <- data |> 
  dplyr::mutate(
    year = lubridate::year(datetime),
    month = lubridate::month(datetime),
    day = lubridate::day(datetime),
    hour = lubridate::hour(datetime)
  ) |> 
    dplyr::select(-c(name, datetime, stations, icon))
  
  # add the datehour_id by joining with datehour table  
  new_weather <- datehour_db_table |> 
    dplyr::collect() |> 
    dplyr::select(-datehour) |> 
    dplyr::inner_join(new_weather_data, by = c("year", "month", "day", "hour")) |> 
    dplyr::select(-c(year, month, hour, day)) |> 
    janitor::clean_names() 
  
  insert_weather <- DBI::dbWriteTable(thermostat_db, "weather", new_weather, append = T) 
  
  if(insert_weather){
    print(glue::glue("Added {nrow(new_weather)} records to weather table."))
  }else{
    print("No records to be added to the weather table.")
  }
  
  DBI::dbDisconnect(thermostat_db)
  
}

#' Find dates that are present in the datehour table but do not have 
#' weather records yet and include the latitude and longitude info fom the 
#' thermostat table 
#'
#' @param db A SQLite database file
#'
#' @return a tibble with date, lat and long as columns, 
#' with one row per date
get_dates_to_query_weather <- function(db){
  # browser()
  if(file.exists(db) == FALSE){
    bullets <- c(
      "The provided database file does not exist",
      "Please, provide a correct database file"
    )
    cli::cli_abort(bullets)
  }
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), db)
  # check if the provided database contains the tables
  tables <- list("datehour", "thermostat", "weather")
  purrr::walk(tables, check_table_exist, db = db)
  
  # get the datehour records 
  datehour_db_table <- dplyr::tbl(thermostat_db, "datehour")
  # get the thermostat records for the latitude and longitude
  thermostat_db_table <- dplyr::tbl(thermostat_db, "thermostat")
  # get the existing weather records
  weather_db_table <- dplyr::tbl(thermostat_db, "weather")
  # find the timehour records that don't have weather data yet
  existing_weather_records <- weather_db_table |> 
    dplyr::collect() |> 
    dplyr::pull(datehour_id)
  # get dates that do not have weather records yet
  # visualcrossing returns data for each hour in a day
  # so we get the distinct days from the datehour table
  # for which there is not weather data yet together with the
  # latitude and longitude from the thermostat table
  output <- thermostat_db_table |> 
    dplyr::select(datehour_id, latitude, longitude) |> 
    dplyr::distinct() |> 
    dplyr::right_join(datehour_db_table, by = "datehour_id") |>
    dplyr::filter(!datehour_id %in% existing_weather_records) |> 
    dplyr::distinct(latitude, longitude, year, month, day)  |> 
    dplyr::collect() |> 
    dplyr::mutate(
      date = lubridate::ymd(glue::glue("{year}-{month}-{day}"))
      ) |> 
    dplyr::select(date, lat = latitude, long = longitude)
  
  DBI::dbDisconnect(thermostat_db)
  
  return(output)
}

#' Populate the weather table table
#'
#' @param db A SQLite database file
#'
#' @return Does not return any object
populate_weather_table <- function(db, api.key){
  # browser()
  if(file.exists(db) == FALSE){
    bullets <- c(
      "The provided database file does not exist",
      "Please, provide a correct database file"
    )
    cli::cli_abort(bullets)
  }
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), db)
  # check if the provided database contains the tables
  tables <- list("datehour", "thermostat", "weather")
  purrr::walk(tables, check_table_exist, db = db)
  # get dates present in the datahour table that don't
  # have a weather record yet
  dates <- get_dates_to_query_weather(db)
  # loop over the dates, request data from Visual Crossing
  # and add it to the weather table
  purrr::pwalk(dates, add_one_weather_record, 
              db = db, api.key = api.key)
  
  DBI::dbDisconnect(thermostat_db)
}

#' Populate all tables of the database
#'
#' @param file Path to a single netatmo export file
#' @param dir Path to a directory containing multiple netatmo export file
#' @param db A SQLite database file
#' @param api.key The API key for Visual Crossing service
#' @return_path logical, if TRUE, the path to the populated database file is returned
#'
#' @return If return_path is FALSE, does not return any object. 
#' If TRUE, returns the path to the populated database file
populate_db <- function(file = NULL, dir = NULL, db, api.key, return_path){
  
  if(file.exists(db) == FALSE){
    bullets <- c(
      "The provided database file does not exist",
      "Please, provide a correct database file"
    )
    cli::cli_abort(bullets)
  }
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), db)
  # check if the provided database contains the tables
  tables <- list("datehour", "thermostat", "weather")
  purrr::walk(tables, check_table_exist, db = db)
  
  if (is.null(file) & is.null(dir)) {
    bullets <- c(
      "No export data provided.",
      "Please, provide either the path to single file or a directory"
    )
    cli::cli_abort(bullets)
  } else if(is.null(file) == F & is.null(dir) == F) {
    bullets <- c(
      "Both a single file and a directory were provided.",
      "Please, provide one of the two"
    )
    cli::cli_abort(bullets)
  }else if(is.null(file)){
    files <- list.files(dir, full.names = T) 
    # loop over all files in the directory and add populate the database
    purrr::walk(files, populate_thermostat_tb, db = db)
  }else{
    populate_thermostat_tb(path, db)
  }
  populate_weather_table(db, api.key)
  
  DBI::dbDisconnect(thermostat_db)
  
  if(return_path){
    return(db)
  }
}