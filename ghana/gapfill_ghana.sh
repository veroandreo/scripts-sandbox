#!/usr/bin/bash

########################################################################
# Script to partially gap-fill LST and VI variables 
# Author: Veronica Andreo
# Date: April, 2018
########################################################################

# call this script with:
# grass75svn /run/media/veroandreo/7C906E4D1F910882/grassdata_ghana/latlon_wgs84/ghana --exec sh gapfill_ghana.sh 

#########################
# Export GRASS variables 
#########################

export GRASS_OVERWRITE=1
export GRASS_COMPRESSOR=ZSTD
export GRASS_COMPRESS_NULLS=1


########################################
# Extend limit for number of open files
########################################

ulimit -n 4096


################
# Set variables
################

VI_VARS=(EVI_16day NDVI_16day NDWI_16day NDDI_16day)
LST_VARS=(LST.Day_8day LST.Night_8day)
SERIES=(LST.Day_8day LST.Night_8day EVI_16day NDVI_16day NDWI_16day NDDI_16day)


##############
# GAP-FILLING 
##############

g.region -p region=ghana


############################################
# LWR to fill gaps up to 8 time steps in VI
############################################

for VI_VAR in ${VI_VARS[*]} ; do

 # get list of maps
 t.rast.list -u input=${VI_VAR} column=name output=${VI_VAR}_maplist
 
 if [ "${VI_VAR}" == "NDDI_16day" ] ; then
  
  # LWR NDDI
  r.series.lwr -i file=${VI_VAR}_maplist suffix=_lwr order=2 \
   weight=tricube maxgap=8 range=-100000,100000
 
 elif [ "${VI_VAR}" == "NDWI_16day" ] ; then
  
  # LWR NDWI
  r.series.lwr -i file=${VI_VAR}_maplist suffix=_lwr order=2 \
   weight=tricube maxgap=8 range=-10000,10000
  
 else
  
  # LWR EVI & NDVI
  r.series.lwr -i file=${VI_VAR}_maplist suffix=_lwr order=2 \
   weight=tricube maxgap=8 range=-2000,10000
 
 fi
 
 # extract var from strds name: i.e. NDVI, EVI, NDWI and NDDI
 VAR=`echo $VI_VAR | cut -d'_' -f1`
 echo $VAR
 
 if [ "${VAR}" == "EVI" ] || [ "${VAR}" == "NDVI" ] ; then
 
  # this cycle works only for EVI and NDVI, 
  # NDDI and NDWI have a different name pattern  
  for mapname in `g.list type=raster pattern=MOD13A2*_${VAR}_filt_lwr` ; do
   # parse file names
   year_start=`echo ${mapname:9:4}`
   doy_start=`echo ${mapname:13:3}`
   # convert YYYY-DOY to YYYY-MM-DD
   doy_start=`echo "$doy_start" | sed 's/^0*//'`

   # generate end_date
   if [ $doy_start -lt "353" ] ; then
    doy_end=$(( $doy_start + 15 ))
   elif [ $doy_start -eq "353" ] ; then 
    if [ $[$year_start % 4] -eq 0 ] && [ $[$year_start % 100] -ne 0 ] || [ $[$year_start % 400] -eq 0 ] ; then
    doy_end=$(( $doy_start + 13 ))
    else
    doy_end=$(( $doy_start + 12 ))
    fi
   fi

   START_DATE=`date -d "${year_start}-01-01 +$(( ${doy_start} - 1 ))days" +%Y-%m-%d`
   END_DATE=`date -d "${year_start}-01-01 +$(( ${doy_end} ))days" +%Y-%m-%d`

   # print mapname, start and end date
   echo "$mapname|$START_DATE|$END_DATE" >> ${VI_VAR}_map_list_start_and_end_time_lwr.txt
  done
 
 else

  for mapname in `g.list type=raster pattern="${VAR}_16day_*_lwr"` ; do
   # parse file names
   year_start=`echo ${mapname:11:4}`
   month_start=`echo ${mapname:16:2}`
   day_start=`echo ${mapname:19:2}`
   
   START_DATE=`echo $year_start"-"$month_start"-"$day_start`
   echo "$mapname|$START_DATE" >> ${VI_VAR}_map_list_start_and_end_time_lwr.txt

  done

 fi
 
 # create time series
 t.create type=strds temporaltype=absolute output=${VI_VAR}_lwr \
  title="LWR - ${VI_VAR} MOD13A2.006" \
  description="LWR - ${VI_VAR} MOD13A2.006. Ghana, 2009-2017"

 # register separate time series for Day and Night
 t.register input=${VI_VAR}_lwr file=${VI_VAR}_map_list_start_and_end_time_lwr.txt
 
 if [ "${VAR}" == "NDWI" ] || [ "${VAR}" == "NDDI" ] ; then
  t.snap type=strds input=${VI_VAR}_lwr
 fi
 
 t.info ${VI_VAR}_lwr
 
 # remove file list
 rm -f ${VI_VAR}_maplist ${VI_VAR}_map_list_start_and_end_time_lwr.txt

done


##############################################
# LWR to fill gaps up to 10 time steps in LST
##############################################

for LST_VAR in ${LST_VARS[*]} ; do 

 # list of maps
 t.rast.list -u input=${LST_VAR} column=name output=${LST_VAR}_maplist

 # LWR
 r.series.lwr -i file=${LST_VAR}_maplist suffix=_lwr order=2 \
  weight=tricube maxgap=10 range=10000,17000

 # extract var from strds name: i.e. LST.Day and LST.Night
 VAR=`echo $LST_VAR | cut -d'_' -f1 | sed -e 's/\./_/g'`
 VAR=`echo ${VAR}"_1km"`
 
 for mapname in `g.list type=raster pattern=MOD11A2*_${VAR}_filt_lwr` ; do
    
  # parse file names
  year_start=`echo ${mapname:9:4}`
  doy_start=`echo ${mapname:13:3}`
  # convert YYYY-DOY to YYYY-MM-DD
  doy_start=`echo "$doy_start" | sed 's/^0*//'`

  # generate end_date
  if [ $doy_start -le "353" ] ; then
   doy_end=$(( $doy_start + 8 ))
  elif [ $doy_start -eq "361" ] ; then 
   if [ $[$year_start % 4] -eq 0 ] && [ $[$year_start % 100] -ne 0 ] || [ $[$year_start % 400] -eq 0 ] ; then
    doy_end=$(( $doy_start + 6 ))
   else
    doy_end=$(( $doy_start + 5 ))
   fi
  fi

  START_DATE=`date -d "${year_start}-01-01 +$(( ${doy_start} - 1 ))days" +%Y-%m-%d`
  END_DATE=`date -d "${year_start}-01-01 +$(( ${doy_end} - 1 ))days" +%Y-%m-%d`

  # print mapname, start and end date
  echo "$mapname|$START_DATE|$END_DATE" >> ${LST_VAR}_map_list_start_and_end_time_lwr.txt
  
 done
 
 # create time series container 
 t.create type=strds temporaltype=absolute output=${LST_VAR}_lwr \
  title="LWR - ${LST_VAR} MOD11A2.006" \
  description="LWR - ${LST_VAR} MOD11A2.006. Ghana, 2009-2017"

 # register separate time series for Day and Night
 t.register input=${LST_VAR}_lwr file=${LST_VAR}_map_list_start_and_end_time_lwr.txt
 
 t.info ${LST_VAR}_lwr
 
 # remove file list
 rm -f ${LST_VAR}_maplist ${LST_VAR}_map_list_start_and_end_time_lwr.txt

done


#######################################################
# Estimate Q3 and Q1 per series and filter LWR outputs
#######################################################

for SERIE in ${SERIES[*]} ; do

 VAR=`echo $SERIE | cut -d'_' -f1` ; echo $VAR

 # Q3
 t.rast.series input=${SERIE} \
  method=quart3 \
  output=q3_${SERIE}
 
 # Q1
 t.rast.series input=${SERIE} \
  method=quart1 \
  output=q1_${SERIE}
 
 # Q3 + 1.5*(Q3-Q1)
 r.mapcalc \
  expression="upper_${SERIE} = q3_${SERIE} + (1.5*(q3_${SERIE} - q1_${SERIE}))"
 
 # Q1 - 1.5*(Q3-Q1)
 r.mapcalc \
  expression="lower_${SERIE} = q1_${SERIE} - (1.5*(q3_${SERIE} - q1_${SERIE}))"
 
 # filter > Q3+1.5*(Q3-Q1) & < Q1-1.5*(Q3-Q1)
 t.rast.mapcalc inputs=${SERIE}_lwr output=${SERIE}_lwr_filt \
  expression="if(${SERIE}_lwr > upper_${SERIE} || ${SERIE}_lwr < lower_${SERIE}, null(), ${SERIE}_lwr)" \
  basename=${VAR}_lwr_filt

done
  
########################################################################
# DIRTY HACK!!! 
# Change date to Nov 2012 and Nov 2016 maps in VI 16 days 
# series so they get properly aggregated by month further on.
# See my report at: 
# http://osgeo-org.1560.x6.nabble.com/t-rast-aggregate-problem-with-sampling-methods-td5362499.html
########################################################################

SERIES_VI=(EVI_16day NDVI_16day NDWI_16day NDDI_16day)

for SERIE in ${SERIES_VI[*]} ; do

 VAR=`echo $SERIE | cut -d'_' -f1` ; echo $VAR

 t.register --o input=${SERIE}_lwr_filt map=${VAR}_lwr_filt_090 \
  start="2012-11-16" end="2012-12-01"

 t.register --o input=${SERIE}_lwr_filt map=${VAR}_lwr_filt_182 \
  start="2016-11-16" end="2016-12-01"
  
done


exit
