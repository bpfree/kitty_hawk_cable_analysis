##########################
### 3. Oyster Habitats ###
##########################

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

# Dissolve oyster habitat function
## This function will take the imported data and reduce it down to a single feature.
clean_oyster <- function(oyster_data){
  oyster_layer <- oyster_data %>%
    # reproject the coordinate reference system
    sf::st_transform("EPSG:5070") %>%
    # have only the oyster data that exists study area
    sf::st_intersection(study_area) %>%
    # create field to define as "oyster"
    dplyr::mutate(layer = "oyster") %>%
    # group all features by the "layer" and "value" fields to then have a single feature
    # "value" will get pulled in from the study area layer
    dplyr::group_by(layer,
                    value) %>%
    # summarise the single feature
    dplyr::summarise()
  return(oyster_layer)
}

#####################################
#####################################

# Set directories
## Define data directories (as this is an R Project, pathnames are simplified)
### Texas Parks and Wildlife
copano_bay_dir <- "data/a_raw_data/copano-bay-habitat-classification-shapefiles"
espiritu_santo_dir <- "data/a_raw_data/espiritu-santo-oyster-habitat-shapefiles"
galveston_bay_dir <- "data/a_raw_data/galveston-bay-habitat-classification-shapefiles"
lavaca_tres_palacios_dir <- "data/a_raw_data/lavaca-tres-palacios-habitat-shapefile"
west_galveston_dir <- "data/a_raw_data/west-galveston-bay-habitat-classification-shapefiles"

oyster_restoration_dir <- "data/a_raw_data/tpwd-oyster-restoration-sites"

### Gulf of Mexico
gom_dir <- "data/a_raw_data/Oysters_GOM_2011"

## Input directories
nrc_dir <- "data/a_raw_data/gom_ec_nrc.gdb"

### Output directories
#### Analysis directory
analysis_gpkg <- "data/c_analysis_data/gom_cable_study.gpkg"

#### Intermediate directory
oyster_gpkg <- "data/b_intermediate_data/gom_oyster.gpkg"

#####################################

# View layer names within geopackage
sf::st_layers(dsn = analysis_gpkg,
              do_count = TRUE)

#####################################
#####################################

# Set parameters
## designate region name
region <- "cars"

#####################################
#####################################

# Load study area (to clip habitats to only that area)
study_area <- sf::st_read(dsn = analysis_gpkg, layer = "gom_study_area_marine")

#####################################
#####################################

# Load oyster layers
## Texas Parks & Wildlife (https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/)
### Copano Bay survey (2015) (source: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/copano-bay-habitat-classification-shapefiles.zip)
### Metadata: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/copano-bay-metadata.docx
### ***Note: None of these data fall within the present study area
copano_bay_data <- sf::st_read(dsn = copano_bay_dir, layer = "Copano_Habitats_WGSUTM14N") %>%
  clean_oyster()

#####################################

### Espiritu Santo survey (source: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/espiritu-santo-oyster-habitat-shapefiles.zip)
### Metadata: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/espiritu-santo-metadata.docx
### ***Note: None of these data fall within the present study area
espiritu_santo_data <- sf::st_read(dsn = espiritu_santo_dir, layer = "EspirituSanto_OysterShellHabitat_2017") %>%
  clean_oyster()

#####################################

### Galveston Bay survey (2004 - 2015) (source: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/galveston-bay-habitat-classification-shapefiles.zip)
### Metadata: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/galveston-bay-metadata.zip
galveston_bay_data <- sf::st_read(dsn = galveston_bay_dir, layer = "2019Delineation") %>%
  clean_oyster()

#####################################

### Lavaca and Tres Palacios survey (source: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/lavaca-tres-palacios-habitat-shapefile.zip)
### Metadata: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/lavaca-tres-palacios-metadata.zip
### ***Note: None of these data fall within the present study area
lavaca_tres_palacios_data <- sf::st_read(dsn = lavaca_tres_palacios_dir, layer = "OysterHabitat_LavacaTP_Merge") %>%
  clean_oyster()

#####################################

### West Galveston Bay survey (source: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/west-galveston-bay-habitat-classification-shapefiles.zip)
### Metadata: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/west-galveston-bay-metadata.zip
west_galveston_bay_data <- sf::st_read(dsn = west_galveston_dir, layer = "WestGalvestonBay_OysterHabitatMap_TPWD2016") %>%
  clean_oyster()

#####################################

### Oyster restoration sites (source: https://tpwd.texas.gov/landwater/water/habitats/coastal-fisheries-habitat-assessment-team/resources/tpwd-oyster-restoration-sites.zip)
oyster_restoration_data <- sf::st_read(dsn = oyster_restoration_dir, layer = "TPWD_Oyster_Restoration_Sites") %>%
  clean_oyster()

#####################################

### Gulf of Mexico Atlas (2011) -- American oyster (source: https://www.sciencebase.gov/catalog/item/594830afe4b062508e344418)
### Alternative Gulf of Mexico source: https://www.ncei.noaa.gov/waf/data-atlas-waf/living-marine/documents/Oysters_GOM_2011.zip
### Gulf of Mexico Metadata: https://www.ncei.noaa.gov/maps/gulf-data-atlas//Metadata/ISO/Oysters_GOM_2011.html
#### Texas only: https://www.ncei.noaa.gov/waf/data-atlas-waf/living-marine/documents/Oysters_TX_2011.zip
#### Texas metadata: https://www.ncei.noaa.gov/maps/gulf-data-atlas//Metadata/ISO/Oysters_TX_2011.html
#### ***Note: To download Texas only data:
####    1.) Visit: https://www.ncei.noaa.gov/maps/gulf-data-atlas/atlas.htm
####    2.) Click "Living Marine Resources" tab to display dropdown
####    3.) Navigate to "Invertebrates"
####    4.) Click "1. Eastern Oyster"
####    5.) On right panel, click "More Information"
####    6.) Click on folder icon next to "Data Download / Access Links"
####    7.) Click blue "Download" hyperlinked text for Texas
gom_atlas_data <- sf::st_read(dsn = gom_dir, layer = "Oysters_GOM_2011") %>%
  clean_oyster()

#####################################

### Lavaca oysters harper (2002)
### ***Note: None of these data fall within the present study area
lavaca_oyster_harper <- sf::st_read(dsn = nrc_dir, layer = "Lavaca_Oysters_Harper_2002") %>%
  # change the field "Shape" to be "geometry" so it matches the other data layer field names
  dplyr::rename("geometry" = "Shape") %>%
  clean_oyster()

### Oyster reefs NOAA (2007)
### ***Note: None of these data fall within the present study area
noaa_oyster_reefs <- sf::st_read(dsn = nrc_dir, layer = "OysReef_NOAAAtlas2007_SAB") %>%
  # change the field "Shape" to be "geometry" so it matches the other data layer field names
  dplyr::rename("geometry" = "Shape") %>%
  clean_oyster()

### Powell (1995)
#### ***Note: While the data are not publicly available for download, the data can be viewed
#### on the Texas GLO Coastal Resource Map viewer page: https://cgis.glo.texas.gov/rmc/index.html
#### Click on the layers symbol and under the "Sensitive Areas" group layer, mark "Oysters"
#### The data layer of interest is the "Oyster Habitat"
powell_1995 <- sf::st_read(dsn = nrc_dir, layer = "Oysters_Powell_1995") %>%
  # change the field "Shape" to be "geometry" so it matches the other data layer field names
  dplyr::rename("geometry" = "Shape") %>%
  clean_oyster()

### Oyster lease areas (2018)
#### ***Note: While the data are not publicly available for download, the data are viewable
#### on the Texas HHS Shellfish ArcMap page:
#### https://txdshsea.maps.arcgis.com/apps/webappviewer/index.html?id=801ef406eada4f88b19d960b57d5d680
#### Click on the layers symbol and mark the "Private Oyster Leases" to view the data
#### Contact for the data is Christine Jensen (Christine.Jensen@tpwd.texas.gov)
oyster_lease_2018 <- sf::st_read(dsn = nrc_dir, layer = "oyster_leases_2018") %>%
  # change the field "Shape" to be "geometry" so it matches the other data layer field names
  dplyr::rename("geometry" = "Shape") %>%
  clean_oyster()

## Oyster lease (Texas)
### ***Note: None of these data fall within the present study area
oyster_lease <- sf::st_read(dsn = nrc_dir, layer = "LeaseFind_220823_Oyster") %>%
  # filter data for just ones in Texas's jurisdiction
  dplyr::filter(STATE == "TX") %>%
  clean_oyster()

#####################################

# Combine oyster layers
oyster_study_area <- copano_bay_data %>%
  # bind all datasets as unique rows
  rbind(espiritu_santo_data,
        galveston_bay_data,
        lavaca_tres_palacios_data,
        west_galveston_bay_data,
        oyster_restoration_data,
        gom_atlas_data,
        lavaca_oyster_harper,
        noaa_oyster_reefs,
        powell_1995,
        oyster_lease_2018) %>%
  clean_oyster()

#####################################
#####################################

# Export data
## Analysis geopackage
sf::st_write(oyster_study_area, dsn = analysis_gpkg, layer = "oyster", append = F)

## Oyster geopackage
sf::st_write(oyster_study_area, dsn = oyster_gpkg, layer = "oyster", append = F)

sf::st_write(copano_bay_data, dsn = oyster_gpkg, layer = "copano_bay_survey", append = F)
sf::st_write(espiritu_santo_data, dsn = oyster_gpkg, layer = "espiritu_santo_survey", append = F)
sf::st_write(galveston_bay_data, dsn = oyster_gpkg, layer = "galveston_bay_survey", append = F)
sf::st_write(lavaca_tres_palacios_data, dsn = oyster_gpkg, layer = "lavaca_tres_palacios_survey", append = F)
sf::st_write(west_galveston_bay_data, dsn = oyster_gpkg, layer = "west_gavelston_bay_survey", append = F)
sf::st_write(oyster_restoration_data, dsn = oyster_gpkg, layer = "oyster_restoration_sites", append = F)
sf::st_write(gom_atlas_data, dsn = oyster_gpkg, layer = "gom_atlas", append = F)
sf::st_write(lavaca_oyster_harper, dsn = oyster_gpkg, layer = "lavaca_oyster_harper", append = F)
sf::st_write(noaa_oyster_reefs, dsn = oyster_gpkg, layer = "noaa_oyster_reefs", append = F)
sf::st_write(powell_1995, dsn = oyster_gpkg, layer = "powell_1995", append = F)
sf::st_write(oyster_lease_2018, dsn = oyster_gpkg, layer = "oyster_lease_2018", append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
