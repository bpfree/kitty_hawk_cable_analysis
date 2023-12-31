########################
### 23. NEXRAD Sites ###
########################

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
input_dir <- "data/a_raw_data"

### Output directories
#### Analysis directory
analysis_gpkg <- "data/c_analysis_data/gom_cable_study.gpkg"

#### Intermediate directory
nexrad_gpkg <- "data/b_intermediate_data/nexrad.gpkg"

#####################################
#####################################

# Load study area (to clip habitats to only that area)
study_area <- st_read(dsn = analysis_gpkg, layer = "gom_study_area_marine")

#####################################

# NEXRAD data are maintained on this site: https://www.roc.noaa.gov/WSR88D/
# To obtain the data, do the following:
## 1.) On left panel, navigate to Site ID / Maps
## 2.) Within that option, select Site ID Database
## 3.) On new page, click "Advanced Search" (page: https://www.roc.noaa.gov/WSR88D/Program/SiteID.aspx)
## 4.) Select states of interest (e.g., Louisiana and Texas) from State/Country box
##    ***Note: Can keep option as "Like"
##    ***Note: To select multiple states, click on states of interest while pressing "Control" (or equivalent of control)
## 5.) Click "Search"
## 6.) Select "Longitude" and "Latitude" as column fields
## 7.) Select "Save To Excel"

## ***Note: Longitude and latitude data are as degree-minutes-seconds, so need to convert to decimal degrees

nexrad_sites <- read.csv(paste(input_dir, "nexrad_sites.csv", sep = "/")) %>%
  # convert to data frame
  as.data.frame() %>%
  # remove any times longitude equals "" [see: list(unique(nexrad_sites$Lon.)) -- for all fields are characters (str(nexrad_sites))]
  dplyr::filter(Lon. != "") %>%
  # rename fields
  dplyr::rename("lat" = "Lat.",
                "lon" = "Lon.",
                "site_name" = "Site.Name.") %>%
  # select only fields of importance
  dplyr::select(site_name,
                lon,
                lat) %>%
  # fix site names and create field called "layer" and fill with "nexrad" for summary
  dplyr::mutate(across(site_name, str_to_title),
                layer = "nexrad") %>%
  # Separate longitude
  tidyr::separate(lon, into=c("lon_d", "lon_m", "lon_s"), sep=" ", remove=T, convert = T) %>%
  # Separate latitude
  tidyr::separate(lat, into=c("lat_d", "lat_m", "lat_s"), sep=" ", remove=T, convert = T) %>%
  # convert to longitude and latitude into decimal degrees (degrees + minutes / 60 + seconds / (60 * 60))
  # ***Note: longitude values are multiplied by -1 as they are in the west of the Prime Meridian
  dplyr::mutate(lon_dd = -1 * (-1 * lon_d + lon_m /60 + lon_s/60^2),
                lat_dd = lat_d + lat_m /60 + lat_s/60^2) %>%
  # select only site, longitude, latitude
  dplyr::select(site_name,
                layer,
                lon_dd,
                lat_dd) %>%
  # convert to simple feature
  sf::st_as_sf(coords = c("lon_dd", "lat_dd"),
               # set the coordinate reference system to WGS84
               crs = 4326) %>% # EPSG 4326 (https://epsg.io/4326)
  # reproject the coordinate reference system to match study area data (EPSG:5070)
  sf::st_transform("EPSG:5070") %>% # EPSG 5070 (https://epsg.io/5070)
  # group all features by the "layer" and "value" fields to then have a single feature
  # "value" will get pulled in from the study area layer
  dplyr::group_by(layer) %>%
  # summarise data to obtain single feature
  dplyr::summarise()

#####################################

## Check units for determining cellsize of grid
sf::st_crs(nexrad_sites, parameters = TRUE)$units_gdal

#####################################

# NEXRAD sites with 35 kilometer buffer
nexrad35km <- nexrad_sites %>%
  #  add a setback (buffer) distance of 35km (35,000 meters)
  sf::st_buffer(35000)

# NEXRAD sites with 35 - 70 kilometer bufer
nexrad35_70km <- nexrad_sites %>%
  #  add a setback (buffer) distance of 70km (70,000 meters)
  sf::st_buffer(70000) %>%
  # remove the 35km buffer
  sf::st_difference(nexrad35km) %>%
  dplyr::select(-layer.1)

#####################################

g <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = nexrad35km, color = "blue", fill= "NA") +
  ggplot2::geom_sf(data = nexrad35_70km, color = "black", linetype = "dashed", fill = "NA")
g

#####################################
#####################################

# Obtain data only in study area
nexrad35km_ioi <- nexrad35km %>%
  # obtain only NEXRAD 35km buffer in the study area
  sf::st_intersection(study_area)

nexrad70km_ioi <- nexrad35_70km %>%
  # obtain only NEXRAD 35km buffer in the study area
  sf::st_intersection(study_area)

#####################################

g2 <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = study_area, color = "red", fill = NA) +
  ggplot2::geom_sf(data = nexrad35km_ioi, color = "blue", fill= NA) +
  ggplot2::geom_sf(data = nexrad70km_ioi, color = "black", linetype = "dashed", fill = NA)
  
g2

#####################################
#####################################

# Export data
## Analysis geopackage
sf::st_write(obj = nexrad35km_ioi, dsn = analysis_gpkg, "nexrad35km", append = F)
sf::st_write(obj = nexrad70km_ioi, dsn = analysis_gpkg, "nexrad70km", append = F)

## NEXRAD geopackage
sf::st_write(obj = nexrad35km_ioi, dsn = nexrad_gpkg, "nexrad35km", append = F)
sf::st_write(obj = nexrad70km_ioi, dsn = nexrad_gpkg, "nexrad70km", append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate