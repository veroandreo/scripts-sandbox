#!/usr/bin/bash

########################################################################
# Mosaic, reproject, subset and import MOD11A2.006 and MOD13A2.006
# Author: Veronica Andreo
# Date: April, 2018
########################################################################

# before running this script, create grass database and location in external disk
# mkdir /run/media/veroandreo/7C906E4D1F910882/grassdata_ghana
# grass75svn -c EPSG:4326 /run/media/veroandreo/7C906E4D1F910882/grassdata_ghana/latlon_wgs84 -e

# call this script with:
# grass75svn /run/media/veroandreo/7C906E4D1F910882/grassdata_ghana/latlon_wgs84/ghana --exec sh import_modis_ghana.sh 

#########################
# Export GRASS variables 
#########################

export GRASS_OVERWRITE=1
export GRASS_COMPRESSOR=ZSTD
export GRASS_COMPRESS_NULLS=1

################
# Set variables 
################

PRODUCTS=(MOD11A2.006 MOD13A2.006)
DATA_FOLDER=/run/media/veroandreo/7C906E4D1F910882/GHANA
VARS_MOD11=(LST_Day_1km LST_Night_1km QC_Day QC_Night)
VARS_MOD13=(NDVI EVI NIR_reflectance MIR_reflectance pixel_reliability)

###########################################################
# Import Ghana boundaries (0 to 2 adm level) and districts
###########################################################

for i in `seq 0 2` ; do 
 v.in.ogr \
  input=$HOME/Documents/itc_utwente/frank_malaria_ghana/GHA_adm${i}.shp \
  output=GHA_adm${i}
done

v.import \
 input=$HOME/Documents/itc_utwente/frank_malaria_ghana/Ghana_Districts.shp \
 output=GHA_districts snap=0.1

# clean vector
v.clean input="GHA_districts" layer="-1" type="boundary,area" \
 output="GHA_districts_clean" tool="rmarea" threshold=100000

#################
# Region setting
#################

# import test raster map
r.import \
 input=$HOME/Documents/itc_utwente/frank_malaria_ghana/LST_mosaic.tif \
 output=mosaic_test
 
# check info
r.info mosaic_test

# create and switch to new mapset
g.mapset -c mapset=ghana
g.mapset -p

# set region to vector extent and align res to test raster
g.region -p vector=GHA_districts_clean align=mosaic_test grow=2 save=ghana

eval `g.region -g`

########################
# Import all MODIS data
########################

for PRODUCT in ${PRODUCTS[*]} ;  do

 if [ "${PRODUCT}" == "MOD11A2.006" ] ; then
 
  cd $DATA_FOLDER/$PRODUCT
 
  # create sorted list of hdf files 
  ls *.hdf | sort > list_${PRODUCT}.txt  
 
  echo "------------------- MOSAICING $PRODUCT -------------------------"
 
  # keep LST_Day, QC_Day, LST_Night & QC_Night
  modis_mosaic.py -v -s "1 1 0 0 1 1 0 0 0 0 0 0" list_${PRODUCT}.txt

  echo "------------------ MOSAICING $PRODUCT DONE ---------------------"
 
  # convert (reproject & convert into GTiff) - layer by layer, one tif per vrt
  for VAR_MOD11 in ${VARS_MOD11[*]} ; do
  
   # list of unique information
   LIST_DATES=`ls *${VAR_MOD11}.vrt | cut -d'_' -f1` # cut first part: A2015365
  
   for DAY in $LIST_DATES ; do 
   
    # convert to tif and project
    modis_convert.py -v -g 0.008333333333333 -e 4326 -s "(1)" -o ${DAY}_${VAR_MOD11}_mosaic ${DAY}_None_${VAR_MOD11}.vrt
   
    echo "--------------- CONVERTING $PRODUCT $VAR - $DAY DONE ------------------"
   
    # spatial subseting	
    gdal_translate -of GTiff -projwin $w $n $e $s ${DAY}_${VAR_MOD11}_mosaic.tif ${DAY}_${VAR_MOD11}.tif

    echo "--------------- SUBSETTING $PRODUCT $VAR - $DAY DONE ------------------"

    # import into GRASS
    r.in.gdal input=${DAY}_${VAR_MOD11}.tif output=MOD11A2_${DAY}_${VAR_MOD11}

    echo "---------------- IMPORTING $PRODUCT $VAR - $DAY DONE ------------------"

    # remove vrt and tif files
    rm -f ${DAY}_None_${VAR_MOD11}.vrt ${DAY}_${VAR_MOD11}_mosaic.tif ${DAY}_${VAR_MOD11}.tif
   
    echo "------------- REMOVING vrt AND tif $PRODUCT $VAR - $DAY DONE ---------------"
   
   done
  done	
   
 else
  
  cd $DATA_FOLDER/$PRODUCT ; pwd
  
  # create sorted list of hdf files 
  ls *.hdf | sort > list_${PRODUCT}.txt  
  
  echo "------------------- MOSAICING $PRODUCT -------------------------"
 
  # keep NDVI, EVI, VI quality, MIR, NIR, pixel_reliability
  modis_mosaic.py -v -s "1 1 0 0 1 0 1 0 0 0 0 1" list_${PRODUCT}.txt

  echo "------------------ MOSAICING $PRODUCT DONE ---------------------"
  
  # name massaging
  for FILE in *.vrt ; do
   NEW=`echo "$FILE" | sed -e 's/ /_/g'`
   FINAL=`echo $NEW | sed 's/1_km_16_days_//g'`
   echo $FINAL
   mv -v "$FILE" $FINAL
  done
   
  # convert (reproject & convert into GTiff) - layer by layer, one tif per vrt
  for VAR_MOD13 in ${VARS_MOD13[*]} ; do
  
   # list of unique information
   LIST_DATES=`ls *${VAR_MOD13}.vrt | cut -d'_' -f1` # cut the first part, example: A2015365
  
   for DAY in $LIST_DATES ; do 
   
    # convert to tif and project
    modis_convert.py -g 0.008333333333333 -e 4326 -v -s "(1)" -o ${DAY}_${VAR_MOD13}_mosaic ${DAY}_None_${VAR_MOD13}.vrt
   
    echo "--------------- CONVERTING $PRODUCT $VAR - $DAY DONE ------------------"
   
    # spatial subseting	
    gdal_translate -of GTiff -projwin $w $n $e $s ${DAY}_${VAR_MOD13}_mosaic.tif ${DAY}_${VAR_MOD13}.tif

    echo "--------------- SUBSETTING $PRODUCT $VAR - $DAY DONE ------------------"

    # import into GRASS
    r.in.gdal input=${DAY}_${VAR_MOD13}.tif output=MOD13A2_${DAY}_${VAR_MOD13}

    echo "---------------- IMPORTING $PRODUCT $VAR - $DAY DONE ------------------"

    # remove vrt and tif files
    rm -f ${DAY}_None_${VAR_MOD13}.vrt ${DAY}_${VAR_MOD13}_mosaic.tif ${DAY}_${VAR_MOD13}.tif
   
    echo "------------- REMOVING vrt AND tif $PRODUCT $VAR - $DAY DONE ---------------"
   
   done
  done
  	
 fi
  
done

# import water mask
cd $DATA_FOLDER/MOD44W.006
ls *.hdf > list_mod44w.txt

# keep only water_mask
modis_mosaic.py -v -s "1 0" list_mod44w.txt

echo "----------------- MOSAICING water mask DONE -------------------------"

LIST_DATES=`ls *water_mask.vrt | cut -d'_' -f1` # cut the first part, example: A2010001

for DAY in $LIST_DATES ; do

 # convert to tif and project
 modis_convert.py -g 0.0020833333325 -e 4326 -v -s "(1)" -o ${DAY}_water_mask_mosaic ${DAY}_None_water_mask.vrt

 # spatial subseting	
 gdal_translate -of GTiff -projwin $w $n $e $s ${DAY}_water_mask_mosaic.tif ${DAY}_water_mask.tif

 echo "--------------- SUBSETTING water mask DONE ------------------"

 # import into GRASS
 r.in.gdal input=${DAY}_water_mask.tif output=${DAY}_water_mask

 echo "---------------- IMPORTING water mask DONE ------------------"

 # remove vrt and tif files 
 rm -f ${DAY}_water_mask.vrt ${DAY}_water_mask_mosaic.tif ${DAY}_water_mask.tif
 rm -f list_mod44w.txt

 echo "------------- REMOVING vrt AND tif DONE ---------------"

done
  
exit
