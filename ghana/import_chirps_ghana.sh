#!/usr/bin/bash

########################################################################
# Subset and import CHIRPS
# Author: Veronica Andreo
# Date: April, 2018
########################################################################

# call this script with:
# grass75svn /run/media/veroandreo/7C906E4D1F910882/grassdata_ghana/latlon_wgs84/ghana --exec sh import_chirps_ghana.sh 

#########################
# Export GRASS variables 
#########################

export GRASS_OVERWRITE=1
export GRASS_COMPRESSOR=ZSTD
export GRASS_COMPRESS_NULLS=1

################
# Set variables 
################

DATA_FOLDER=/run/media/veroandreo/7C906E4D1F910882/GHANA/CHIRPS
YEARS=`seq 2009 2017`

#################
# Region setting
#################

g.region -p region=ghana

#####################
# Import CHIRPS data
#####################

for YEAR in $YEARS ; do

 cd $DATA_FOLDER/$YEAR
 
 echo "---------------- IMPORTING CHIRPS YEAR $YEAR --------------------"
 
 for FILE in `ls *.gz` ; do
  
  # uncompress gz files
  gunzip $FILE
  
  # get input and output names
  IN_NAME=`basename $FILE .gz`
  OUT_NAME=`basename $IN_NAME .tif`
  
  # import 
  r.in.gdal -ra input=$IN_NAME output=$OUT_NAME
  
  # set nulls
  r.null map=$OUT_NAME setnull=-9999

 done

 echo "---------------- CHIRPS YEAR $YEAR IMPORTED ---------------------"

done 

exit
