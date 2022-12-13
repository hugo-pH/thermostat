#' Create all tables in the database
#'
#' @param path Path where the SQLite database file will be created
#'
#' @return does not return any object
create_db <- function(path) {
  
  if(file.exists(path) == FALSE){
    
  thermostat_db <- DBI::dbConnect(RSQLite::SQLite(), path)
  
DBI::dbExecute(
thermostat_db,
"CREATE TABLE datehour (
datehour_id INTEGER PRIMARY KEY AUTOINCREMENT,
datehour text,
year integer,
month integer,
day integer,
hour integer
);"
)

  DBI::dbExecute(
    thermostat_db,
    "CREATE TABLE thermostat (
thermostat_id INTEGER PRIMARY KEY,
datetime text,
house_temperature integer,
sp_temp integer,
boiler_on integer,
boiler_off integer,
temp_change integer,
boiler_state integer,
longitude integer,
latitude integer,
datehour_id integer,
FOREIGN KEY(datehour_id) REFERENCES datehour(datehour_id)
);"
  )
  
  DBI::dbExecute(
    thermostat_db,
    "CREATE TABLE weather (
datehour_id INTEGER PRIMARY KEY,
temperature integer,
feelslike integer,
dew integer,
humidity integer,
precip integer,
precipprob integer,
preciptype integer,
snow integer,
snowdepth integer,
windgust integer,
windspeed integer,
winddir integer,
sealevelpressure integer,
cloudcover integer,
visibility integer,
solarradiation integer,
solarenergy integer,
uvindex integer,
severerisk integer,
conditions text,
FOREIGN KEY(datehour_id) REFERENCES datehour(datehour_id)
);"
  )
  DBI::dbDisconnect(thermostat_db)
  
  print(glue::glue("Database created in {path}."))
  
  }else{
    print(glue::glue("Database file already exist in {path}."))
  }
}
