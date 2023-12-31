############################
### 19. Submarine Cables ###
############################

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
## Define data directories (as this is an R Project, pathnames are simplified)
### Input directories
submarine_cable_area_dir <- "data/a_raw_data/SubmarineCableArea/SubmarineCableArea.gpkg"
submarine_cable_dir <- "data/a_raw_data/SubmarineCable/NOAAChartedSubmarineCables.gdb"
geocable_dir <- "data/a_raw_data/u_fouo_sd_geocables_June_2022_distribution/u_fouo_geocable_state_dept_v10_geo_wgs84.gdb"

### Output directories
#### Analysis directory
analysis_gpkg <- "data/c_analysis_data/gom_cable_study.gpkg"

#### Intermediate directory
submarine_cables_gpkg <- "data/b_intermediate_data/submarine_cables.gpkg"

# View layer names within geodatabase
sf::st_layers(dsn = submarine_cable_area_dir,
              do_count = TRUE)

sf::st_layers(dsn = submarine_cable_dir,
              do_count = TRUE)

sf::st_layers(dsn = geocable_dir,
              do_count = TRUE)

#####################################
#####################################

# Load study area (to clip habitats to only that area)
study_area <- sf::st_read(dsn = analysis_gpkg, layer = "gom_study_area_marine")

# Load submarine cable area data (source: https://marinecadastre.gov/downloads/data/mc/SubmarineCableArea.zip)
## Metadata: https://www.fisheries.noaa.gov/inport/item/66190
submarine_cable_areas <- sf::st_read(dsn = submarine_cable_area_dir, layer = "SubmarineCableArea") %>%
  # reproject the coordinate reference system to match study area data (EPSG:5070)
  sf::st_transform("EPSG:5070") %>% # EPSG 5070 (https://epsg.io/5070)
  # filter for only operational submarine cable areas
  # ***Note: Study area has only "Operational" and NA
  # ***Note: Other statuses include: "Inactive", "Abandoned", and "Proposed"
  dplyr::filter(status == "Operational") %>%
  # obtain only submarine cables in the study area
  sf::st_intersection(study_area) %>%
  # create field called "layer" and fill with "submarine cables" for summary
  dplyr::mutate(layer = "submarine_cables") %>%
  # add a setback (buffer) distance of 152.4 meters (500 feet)
  sf::st_buffer(dist = 152.4) %>%
  # group all features by the "layer" and "value" fields to then have a single feature
  # "value" will get pulled in from the study area layer
  dplyr::group_by(layer,
                  value) %>%
  # summarise data to obtain single feature
  dplyr::summarise()

## Check units for determining cellsize of grid
sf::st_crs(submarine_cable_areas, parameters = TRUE)$units_gdal

#####################################

# Load NOAA Charted submarine cable data (source: https://marinecadastre.gov/downloads/data/mc/SubmarineCable.zip)
## Metadata: https://www.fisheries.noaa.gov/inport/item/57238
submarine_cables_noaa <- sf::st_read(dsn = submarine_cable_dir, layer = "NOAAChartedSubmarineCables") %>%
  # change to multilinestring (for 1 features is multicurve: 1171)
  sf::st_cast(to = "MULTILINESTRING") %>%
  # make sure all geometries are valid
  sf::st_make_valid() %>%
  # reproject the coordinate reference system to match study area data (EPSG:5070)
  sf::st_transform("EPSG:5070") %>% # EPSG 5070 (https://epsg.io/5070)
  # obtain only submarine cables in the study area
  sf::st_intersection(study_area) %>%
  # create field called "layer" and fill with "submarine cables" for summary
  dplyr::mutate(layer = "submarine_cables") %>%
  #  add a setback (buffer) distance of 152.4 meters (500 feet)
  sf::st_buffer(dist = 152.4) %>%
  # group all features by the "layer" and "value" fields to then have a single feature
  # "value" will get pulled in from the study area layer
  dplyr::group_by(layer,
                  value) %>%
  # summarise data to obtain single feature
  dplyr::summarise()

## Check units for determining cellsize of grid
sf::st_crs(submarine_cables_noaa, parameters = TRUE)$units_gdal

#####################################

# Load geocable data (source: confidential)
## Data last updated June 2022
geocable <- sf::st_read(dsn = geocable_dir, layer = "u_fouo_geocable_lns_geo_wgs84") %>%
  # reproject the coordinate reference system to match study area data (EPSG:5070)
  sf::st_transform("EPSG:5070") %>% # EPSG 5070 (https://epsg.io/5070)
  # obtain only geocable in the study area
  sf::st_intersection(study_area) %>%
  # create field called "layer" and fill with "submarine cable" for summary
  dplyr::mutate(layer = "submarine_cables") %>%
  # rename geom field
  dplyr::rename("Shape" = "SHAPE") %>%
  #  add a setback (buffer) distance of 152.4 meters (500 feet)
  sf::st_buffer(dist = 152.4) %>%
  # group all features by the "layer" and "value" fields to then have a single feature
  # "value" will get pulled in from the study area layer
  dplyr::group_by(layer,
                  value) %>%
  # summarise data to obtain single feature
  dplyr::summarise()

## Check units for determining cellsize of grid
sf::st_crs(submarine_cables_noaa, parameters = TRUE)$units_gdal

#####################################
#####################################

g <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = submarine_cables_noaa, linetype = "dashed", color = "lightblue") +
  ggplot2::geom_sf(data = geocable, linetype = "dashed", color = "purple") +
  ggplot2::geom_sf(data = study_area, fill = NA, linetype = "dashed", color = "orange")
g

#####################################
#####################################

submarine_cables <- submarine_cable_areas %>%
  # combine submarine cable data
  rbind(submarine_cables_noaa,
        geocable) %>%
  # group data by "layer" and "value" fields
  dplyr::group_by(layer,
                  value) %>%
  # summarise to return single feature
  dplyr::summarise()

#####################################
#####################################

# Export data
## Analysis geopackage
sf::st_write(obj = submarine_cables, dsn = analysis_gpkg, "submarine_cables", append = F)

## Submarine Cables geopackage
sf::st_write(obj = submarine_cables, dsn = submarine_cables_gpkg, "submarine_cables", append = F)

sf::st_write(obj = submarine_cable_areas, dsn = submarine_cables_gpkg, "submarine_cable_areas", append = F)
sf::st_write(obj = submarine_cables_noaa, dsn = submarine_cables_gpkg, "submarine_cable_noaa", append = F)
sf::st_write(obj = geocable, dsn = submarine_cables_gpkg, "geocable", append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate