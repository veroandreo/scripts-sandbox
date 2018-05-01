#!/usr/bin/bash

########################################################################
# Download MOD11A2.006, MOD13A2.006 and MOD44W.006
# Author: Veronica Andreo
# Date: April, 2018
########################################################################

# call this script with:
# sh download_ghana.sh 

# requirements:
# pymodys library (www.pymodis.org)
# register at Earth Data - NASA
# .netcr file with user and password in $HOME:
# machine urs.earthdata.nasa.gov login <username> password <password>

################
# SET VARIABLES 
################

YEAR_START=2009
YEAR_END=2017
TILES="h17v07,h17v08,h18v07,h18v08"
TILES_LIST=(h17v07 h17v08 h18v07 h18v08)
PRODUCTS=(MOD11A2.006 MOD13A2.006 MOD44W.006)
YEARS=`seq 2009 2017`
DOY8=`seq -w 1 8 366`
DOY16=`seq -w 1 16 366`
DATA_FOLDER=/run/media/veroandreo/7C906E4D1F910882/GHANA

###########
# DOWNLOAD
###########

mkdir $DATA_FOLDER
cd $DATA_FOLDER

for PRODUCT in ${PRODUCTS[*]} ; do

 mkdir $PRODUCT ; cd $PRODUCT

 echo "---------------- DOWNLOADING PRODUCT: $PRODUCT ----------------"
  
 modis_download.py -s MOLT -p $PRODUCT -t $TILES -f $YEAR_START-01-01 -e $YEAR_END-12-31 .
  
 echo "----------------- DOWNLOADED PRODUCT: $PRODUCT ----------------"
 
 cd ..

done

################################################
# CHECK FOR EMPTY FILES, MISSING TILES OR DATES
################################################

# check for empty files
find . -type f -size 0b > empty_files
 
# check for missing tiles or dates
cd $DATA_FOLDER/MOD11A2.006

for YEAR in ${YEARS[*]} ; do
 for DOY in ${DOY8[*]} ; do
  for TILE in ${TILES_LIST[*]} ; do
   echo A$YEAR$DOY.$TILE >> list_complete
  done
 done 
done
ls *.hdf | cut -d'.' -f'2,3' > list_exist
diff list_complete list_exist > missing
rm -f list_complete list_exist

echo "Missing maps MOD11A2: "
cat missing

cd $DATA_FOLDER/MOD13A2.006
for YEAR in ${YEARS[*]} ; do
 for DOY in ${DOY16[*]} ; do
  for TILE in ${TILES_LIST[*]} ; do
   echo A$YEAR$DOY.$TILE >> list_complete
  done
 done 
done
ls *.hdf | cut -d'.' -f'2,3' > list_exist
diff list_complete list_exist > missing
rm -f list_complete list_exist

echo "Missing maps MOD13A2: "
cat missing

cd $DATA_FOLDER/MOD44W.006
for YEAR in ${YEARS[*]} ; do
 for TILE in ${TILES_LIST[*]} ; do
  echo A${YEAR}001.${TILE} >> list_complete
 done
done
ls *.hdf | cut -d'.' -f'2,3' > list_exist
diff list_complete list_exist > missing
rm -f list_complete list_exist

echo "Missing maps MOD44W: "
cat missing

cd

exit
