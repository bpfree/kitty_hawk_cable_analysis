#################################
### 21. Environmental Sensors ###
#################################

# Clear environment
rm(list = ls())

# Calculate start time of code (determine how long it takes to complete all code)
start <- Sys.time()

#####################################
#####################################

# Load packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(docxtractr,
               dplyr,
               elsa,
               fasterize,
               fs,
               ggplot2,
               janitor,
               ncf,
               paletteer,
               pdftools,
               plyr,
               purrr,
               raster,
               RColorBrewer,
               reshape2,
               rgdal,
               rgeoda,
               rgeos,
               rmapshaper,
               rnaturalearth, # use devtools::install_github("ropenscilabs/rnaturalearth") if packages does not install properly
               RSelenium,
               sf,
               shadowr,
               sp,
               stringr,
               terra, # is replacing the raster package
               tidyr,
               tidyverse)

#####################################
#####################################

# Set directories
## Define data directory (as this is an R Project, pathnames are simplified)
### Input directories
environmental_sensors_dir <- "data/a_raw_data/environmental_sensors"
ndbc_kml <- "data/a_raw_data/environmental_sensors/stations_by_program.kml"
gcoos_gpkg <- "data/a_raw_data/gcoos_sensors.gpkg"

### Output directories
#### Analysis directory
analysis_gpkg <- "data/c_analysis_data/gom_cable_study.gpkg"

#### Intermediate directory
environmental_sensors_gpkg <- "data/b_intermediate_data/environmental_sensors.gpkg"

#####################################

# View layer names within geodatabase
sf::st_layers(dsn = ndbc_kml,
              do_count = TRUE)

## Layers contained include:
### 1.) International Partners
### 2.) IOOS Partners
### 3.) Marine METAR
### 4.) NDBC Meteorological / Ocean
### 5.) NERRS
### 6.) NOS/CO-OPS
### 7.) Ships
### 8.) TAO
### 9.) Tsunami

#####################################
#####################################

# Load study area (to clip habitats to only that area)
study_area <- sf::st_read(dsn = analysis_gpkg, layer = "gom_study_area_marine")

#####################################
#####################################

# Environmental sensor function
## This function will take the imported data and reduce it to the study area
ndbc_preparation <- function(sensor_data){
  sensor_layer <- sensor_data %>%
    # clean up data
    dplyr::rename("sensor" = "Name") %>%
    # create "status" field
    dplyr::mutate(status = "data collecting")
  return(sensor_layer)
}

clean_sensor <- function(sensor_data){
  sensor_layer <- sensor_data %>%
    # reproject the coordinate reference system
    sf::st_transform("EPSG:5070") %>% # EPSG 5070 (https://epsg.io/5070)
    # obtain sensor data within study area
    sf::st_intersection(study_area) %>%
    # create field called "layer" and fill with "environmental sensor" for summary
    dplyr::mutate(layer = "environmental sensor") %>%
    # select key fields
    dplyr::select(layer, sensor, status, value)
  return(sensor_layer)
}

#####################################
#####################################

# Load environmental sensor data
## NDBC buoy data (source: https://www.ndbc.noaa.gov/kml/marineobs_as_kml.php?sort=pgm)
### Site page: https://www.ndbc.noaa.gov/obs.shtml
### ***Beware: the download link on the NDBC website for the KML data (https://www.ndbc.noaa.gov/kml/marineobs_by_pgm.kml) will not download a usable dataset (as they lack corresponding spatial data)
### ***Note: if really want to use those data, downloaded as a KML and then convert to a shapefile in ArcGIS

#### International Partners
#### ***Note: No data located in study area
ndbc_international_partners <- sf::st_read(dsn = ndbc_kml, layer = "International Partners") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### IOOS Partners
ndbc_ioos_partners <- sf::st_read(dsn = ndbc_kml, layer = "IOOS Partners") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### Marine METAR
ndbc_marine_metar <- sf::st_read(dsn = ndbc_kml, layer = "Marine METAR") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### NDBC Meteorological / Ocean
ndbc_metero_ocean <- sf::st_read(dsn = ndbc_kml, layer = "NDBC Meteorological/Ocean") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### NERRS
#### ***Note: No data located in study area
ndbc_nerrs <- sf::st_read(dsn = ndbc_kml, layer = "NERRS") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### NOS / CO-OPS
ndbc_nos_coops <- sf::st_read(dsn = ndbc_kml, layer = "NOS/CO-OPS") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### Ships
ndbc_ships <- sf::st_read(dsn = ndbc_kml, layer = "Ships") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### TAO
#### ***Note: No data located in study area
ndbc_tao <- sf::st_read(dsn = ndbc_kml, layer = "TAO") %>%
  ndbc_preparation() %>%
  clean_sensor()

#### Tsunami
#### ***Note: No data located in study area
ndbc_tsunami <- sf::st_read(dsn = ndbc_kml, layer = "Tsunami") %>%
  ndbc_preparation() %>%
  clean_sensor()

ndbc_sensor <- ndbc_international_partners %>%
  # combine all cleaned and processed NDBC data
  rbind(ndbc_ioos_partners,
        ndbc_marine_metar,
        ndbc_metero_ocean,
        ndbc_nerrs,
        ndbc_nos_coops,
        ndbc_ships,
        ndbc_tao,
        ndbc_tsunami)

#####################################

## GCOOS Sensors
### Federal Assets (source: https://data.gcoos.org/inventory.php#tabs-3)
#### ***Note: Copano Bay and Copano Bay East have same coordinates (two different sensors)
#### ***Note: Middle Bay and Magnolia River have same coordinates -- seems like incorrect entry
#### ***Note: If objective is to have single sensor, can use the dplyr::distinct() function to return only unique locations (will need to remove sensor and status fields)
gcoos_fed_sensor <- sf::st_read(dsn = gcoos_gpkg, layer = "gcoos_federal_sensor_assets") %>%
  clean_sensor()

#####################################

### Regional Assets (source: https://data.gcoos.org/inventory.php#tabs-2)
#### ***Note: All the regional assets in study are inactive
gcoos_regional_sensor <- sf::st_read(dsn = gcoos_gpkg, layer = "gcoos_regional_sensor_assets") %>%
  clean_sensor()

#####################################

## IOOS Sensors
### ERDDAP page: http://erddap.ioos.us/erddap/index.html
### Datasets: http://erddap.ioos.us/erddap/info/index.html?page=1&itemsPerPage=1000
### 2020 - 2021 data download: http://erddap.ioos.us/erddap/tabledap/raw_asset_inventory.html
### Download link (csv): http://erddap.ioos.us/erddap/tabledap/raw_asset_inventory.csv?crs%2CYear%2CRA%2CStation_ID%2CWMO_ID_or_NWS_CMAN_ID%2CStation_Long_Name%2CStation_Description%2Clatitude%2Clongitude%2CPlatform_Type%2CStation_Deployment%2CCurrently_Operational%2CPlatform_Funder_Sponsor%2CRA_Funding_Involvement%2CPlatform_Operator_Owner%2COperator_Sector%2CPlatform_Maintainer%2CData_Manager%2CVariable_Names_water_column_depth_of_measurement_in_meters_CF_name_m_m_or_CF_name_mult_or_CF_name_depths%2CAdditional_notes%2Cfile
#### Metadata: http://erddap.ioos.us/erddap/info/raw_asset_inventory/index.html
#### Background information: https://github.com/ioos/ioos-asset-inventory/blob/main/README.md
ioos_sensor <- read.csv(paste(environmental_sensors_dir, "environmental_sensors_ioos.csv", sep = "/")) %>%
  # delete the 1st row as it does not contain sensor data
  dplyr::filter(!row_number() %in% c(1)) %>%
  # remove NaN values from longitude and latitude fields
  dplyr::filter(longitude != "NaN") %>%
  # create sensor field to help spot duplicates across datasets
  dplyr::mutate(sensor = word(Station_ID, start = -1, end = -1, sep = fixed(":"))) %>%
  # rename operational field
  ## codes: Y = Yes, N = No, U = Unknown, O = Offline () (http://erddap.ioos.us/erddap/info/raw_asset_inventory/index.html)
  dplyr::rename("status" = "Currently_Operational") %>%
  # keep only needed fields
  dplyr::select(longitude, latitude,
                sensor, status) %>%
  # since longitude and latitude fields are character, need to convert them to numeric so they can be used to set coordinate reference system
  dplyr::mutate(across(c(longitude,
                         latitude),
                       as.numeric)) %>%
  # convert to simple feature
  sf::st_as_sf(coords = c("longitude", "latitude"),
               # set the coordinate reference system to WGS84 (coordinate reference system verified by Matt Biddle (mathew.biddle@noaa.gov))
               # also can see this for verifying: https://github.com/ioos/ioos-asset-inventory/blob/main/inventory_creation.ipynb (section 18)
               crs = 4326) %>% # EPSG 4326 (https://epsg.io/4326)
  clean_sensor()

#####################################
#####################################

# Combine and clean environmental sensor data
environmental_sensor <- ndbc_sensor %>%
  # combine with other sensor datasets
  rbind(gcoos_fed_sensor,
        # this dataset is being added but currently is populated by zero features
        gcoos_regional_sensor,
        ioos_sensor) %>%
  # recode values for the status field so all say the same thing
  dplyr::mutate(status = recode(status,
                                "Y" = "data collecting",
                                "Active" = "data collecting")) %>%
  # remove duplicated buoys / sensors
  # ***Note: 42043 and 42050 both still have 2 records as they have different coordinates; need to determine which is best option
  dplyr::distinct() %>%
  # group all features by the "layer" and "value" fields to then have a single feature
  dplyr::group_by(layer,
                  value) %>%
  # summarise data for buffer generation
  dplyr::summarise() %>%
  #  add a setback (buffer) distance of 500 meters
  sf::st_buffer(dist = 500)

#####################################
#####################################

# Export data
## Analysis geopackage
sf::st_write(obj = environmental_sensor, dsn = analysis_gpkg, "environmental_sensor", append = F)

## Environmental sensor geopackage
sf::st_write(obj = environmental_sensor, dsn = environmental_sensors_gpkg, "environmental_sensor", append = F)

### NDBC sensor
sf::st_write(obj = ndbc_sensor, dsn = environmental_sensors_gpkg, "ndbc_sensor", append = F)
sf::st_write(obj = ndbc_international_partners, dsn = environmental_sensors_gpkg, "ndbc_international_partners", append = F)
sf::st_write(obj = ndbc_ioos_partners, dsn = environmental_sensors_gpkg, "ndbc_ioos_partners", append = F)
sf::st_write(obj = ndbc_marine_metar, dsn = environmental_sensors_gpkg, "ndbc_marine_metar", append = F)
sf::st_write(obj = ndbc_metero_ocean, dsn = environmental_sensors_gpkg, "ndbc_metero_ocean", append = F)
sf::st_write(obj = ndbc_nerrs, dsn = environmental_sensors_gpkg, "ndbc_nerrs", append = F)
sf::st_write(obj = ndbc_nos_coops, dsn = environmental_sensors_gpkg, "ndbc_nos_coops", append = F)
sf::st_write(obj = ndbc_ships, dsn = environmental_sensors_gpkg, "ndbc_ships", append = F)
sf::st_write(obj = ndbc_tao, dsn = environmental_sensors_gpkg, "ndbc_tao", append = F)
sf::st_write(obj = ndbc_tsunami, dsn = environmental_sensors_gpkg, "ndbc_tsunami", append = F)

### GCOOS Federal sensor
sf::st_write(obj = gcoos_fed_sensor, dsn = environmental_sensors_gpkg, "gcoos_federal_sensor", append = F)

### GCOOS Regional sensor
sf::st_write(obj = gcoos_regional_sensor, dsn = environmental_sensors_gpkg, "gcoos_regional_sensor", append = F)

### IOOS sensor
sf::st_write(obj = ioos_sensor, dsn = environmental_sensors_gpkg, "ioos_sensor", append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate