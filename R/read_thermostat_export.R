#' Read a single export file from netatmo thermostat
#'
#' @param path the path to the csv file
#'
#' @return a tibble containing the data from the export
read_netatmo_export <- function(path) {

  df.thermostat.raw <- readr::read_delim(path, delim =  ";", skip = 3, 
                                  col_names = c("timestamp", "datetime", "house_temperature",
                                                "sp_temp","boiler_on", "boiler_off"),
                                  col_types = readr::cols(
                                    timestamp = readr::col_integer(),
                                    datetime = readr::col_datetime(format = "%Y/%m/%d %H:%M:%S"),
                                    house_temperature = readr::col_number(),
                                    sp_temp = readr::col_number(),
                                    boiler_on = readr::col_number(),
                                    boiler_off = readr::col_number()
                                  ),
                                  show_col_types = FALSE)
  
  df.location <- readr::read_delim(path, delim =  ";", 
                                   n_max = 1,
                                   show_col_types = FALSE)
  
  long <- df.location |> dplyr::pull(Long)
  lat  <- df.location |> dplyr::pull(Lat)
  
  df.thermostat.raw |>
    dplyr::mutate(
      temp_change = house_temperature - dplyr::lag(house_temperature),
      boiler_state = (boiler_on / (boiler_on + boiler_off)) * 100,
      longitude = long,
      latitude = lat
    ) 
  
}

