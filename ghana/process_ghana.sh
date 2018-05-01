#!/usr/bin/bash

########################################################################
# Apply QA flags, build strds, estimate NDWI and NDDI, 
# aggregate monthly, get zonal statistics per month
# Author: Veronica Andreo
# Date: April, 2018
########################################################################

# call this script with:
# grass75svn /run/media/veroandreo/7C906E4D1F910882/grassdata_ghana/latlon_wgs84/ghana --exec sh process_ghana.sh 

################
# Requirements: 
################

# add-on: v.strds.stats
# install with:
# g.extension extension=v.strds.stats


#########################
# Export GRASS variables 
#########################

export GRASS_OVERWRITE=1
export GRASS_COMPRESSOR=ZSTD
export GRASS_COMPRESS_NULLS=1


################
# Set variables
################

LST_VARS=(Day Night)
VI_VARS=(NDVI EVI NIR_reflectance MIR_reflectance)
YEARS=`seq 2009 2017`
MONTHS=`seq -w 1 12`

ALL_SERIES=(LST.Day_8day LST.Night_8day EVI_16day NDVI_16day NDWI_16day NDDI_16day precip_daily)
SERIES=(LST.Day_8day LST.Night_8day EVI_16day NDVI_16day NDWI_16day NDDI_16day)
METHODS=(average minimum maximum)
PR_METHODS=(average sum)

NDVI=NDVI_16day
NDWI=NDWI_16day
NDDI=NDDI_16day
NIR=NIR_reflectance_16day
MIR=MIR_reflectance_16day

DATA_FOLDER=/run/media/veroandreo/7C906E4D1F910882/GHANA
OUT_FOLDER=/run/media/veroandreo/7C906E4D1F910882/GHANA/outputs
GRASS_FOLDER=$HOME/software/grass7_trunk


# Start computations...
g.message message="------------ STARTING COMPUTATIONS... -----------------"
g.region -p


#################
# Apply QA flags
#################

for YEAR in ${YEARS[*]} ; do 

 for VAR in ${LST_VARS[*]} ; do
  for m in `g.list rast pat=MOD11A2_A${YEAR}*LST_${VAR}_1km` ; do
   # cut date part of filenames
   i=`echo $m | cut -c 1-16`
   r.mapcalc "${m}_filt = if((${i}_QC_${VAR} & 3) > 1 || ((${i}_QC_${VAR} >> 6) & 3) > 1 || ${m} < 7500, null(), ${m})"
  done
 done
 
 g.message message="----------- DONE QC band application LST YEAR $YEAR --------------" 
 
 for VAR in ${VI_VARS[*]} ; do
  for m in `g.list rast pat=MOD13A2_A${YEAR}*${VAR}` ; do
   # cut date part of filenames
   i=`echo $m | cut -c 1-16`
   r.mapcalc "${m}_filt = if("${i}"_pixel_reliability == 0 || "${i}"_pixel_reliability == 1, ${m}, null())"
  done
 done
 
 g.message message="----------- DONE QC band application VI YEAR $YEAR --------------" 

done

	
####################
# Build time series
####################

t.connect -d

# LST - 8-day 
for VAR in ${LST_VARS[*]} ; do
	
 t.create type=strds temporaltype=absolute output=LST.${VAR}_8day \
  title="LST ${VAR} MOD11A2.006" \
  description="LST ${VAR} MOD11A2.006. Ghana, 2009-2017"

 for mapname in `g.list type=raster pattern=MOD11A2*_LST_${VAR}_1km_filt` ; do
    
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
  echo "$mapname|$START_DATE|$END_DATE" >> LST_${VAR}_map_list_start_and_end_time.txt
  
 done
	
 # register different time series for Day and Night
 t.register input=LST.${VAR}_8day file=LST_${VAR}_map_list_start_and_end_time.txt
  
 t.info input=LST.${VAR}_8day

 t.rast.list input=LST.${VAR}_8day
  
 rm -f LST_${VAR}_map_list_start_and_end_time.txt

done

g.message message="------------- DONE Time Series LST -----------------"


# Vegetation - 16-day 
for VAR in ${VI_VARS[*]} ; do
	
 t.create type=strds temporaltype=absolute output=${VAR}_16day \
  title="${VAR} MOD13A2.006" \
  description="${VAR} MOD13A2.006. Ghana, 2009-2017"

 for mapname in `g.list type=raster pattern=MOD13A2*_${VAR}_filt` ; do
    
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
  echo "$mapname|$START_DATE|$END_DATE" >> ${VAR}_map_list_start_and_end_time.txt
  
 done
	
 # register separate time series for Day and Night
 t.register input=${VAR}_16day file=${VAR}_map_list_start_and_end_time.txt
  
 t.info input=${VAR}_16day

 t.rast.list input=${VAR}_16day
  
 rm -f ${VAR}_map_list_start_and_end_time.txt

done

g.message message="---------- DONE Time Series VEGETATION ---------------"


# Estimate NDWI and NDDI

# NDWI (multiply by 10000 to save as integers)
t.rast.algebra --o basename=${NDWI} suffix=gran \
 expression="${NDWI} = \
 if(${NIR} >= 0.0 && ${MIR} >= 0.0 && ${NIR} <= 10000 && ${MIR} <= 10000, \
 (float(${NIR} - ${MIR}) / (${NIR} + ${MIR}))*10000, \
 null())"

t.info ${NDWI}

g.message message="------------- DONE Time Series NDWI ----------------"

# NDDI (multiply by 10000 to save as integers)
t.rast.algebra --o basename=${NDDI} suffix=gran \
 expression="${NDDI} = (float(${NDVI} - ${NDWI})/(${NDVI} + ${NDWI}))*10000" 

t.info ${NDDI}

g.message message="------------ DONE Time Series NDDI -----------------"


# Precipitation (CHIRPS) - Daily
# the "-" is read as operation in mapcalc or algebra, rename files
g.list type=raster pat=chirps* mapset=. | sed -e 's/-/./g' | sed -e "s/\(.*\)/\1,\1/g" > raster_names.csv
awk -F'.' '{ print $1"-"$2"."$3"."$4"."$5"."$6"."$7"."$8"."$9"."$10"."$11 }' raster_names.csv > to_rename
g.extension extension=g.rename.many
g.message message="--------- RENAMING Precipitation files... -----------"
g.rename.many raster=to_rename

t.create type=strds temporaltype=absolute output=precip_daily \
  title="Precipitation CHIRPS Version 2.0" \
  description="Precipitation CHIRPS Version 2.0. Ghana, 2009-2017"

g.list type=raster pattern="chirps*" output=list_chirps

t.register input=precip_daily file=list_chirps \
 start="2009-01-01" increment="1 day"
 
t.info precip_daily

g.message message="---------- DONE Time Series Precipitation -------------"


######################
# Quantify valid data
######################

# mask
r.mask vector=GHA_districts_clean

# estimating amount of valid data 
for SERIE in ${ALL_SERIES[*]} ; do 

 # yearly counts of valid data
 t.rast.aggregate input=${SERIE} output=${SERIE}_yearly_count_vd \
  basename=${SERIE}_yearly_count_vd suffix=gran \
  method=count granularity="1 years"
 
 # yearly percentages of valid data
 for i in `seq 2009 2017` ; do
  sample=`t.rast.list -u input=${SERIE} columns=name where="strftime('%Y', start_time)='"${i}"'" | wc -l`
  r.mapcalc expression="${SERIE}_yearly_perc_vd_${i} = (${SERIE}_yearly_count_vd_${i}*100.0)/${sample}"
  
  # set comparable color tables
  r.colors map=${SERIE}_yearly_perc_vd_${i} \
   rules=$GRASS_FOLDER/my_viridis_no_percentage
  
  # output simple plots
  d.mon start=cairo resolution=1 \
   output=$OUT_FOLDER/${SERIE}_yearly_perc_vd_${i}.png
  d.rast map=${SERIE}_yearly_perc_vd_${i}
  d.legend raster=${SERIE}_yearly_perc_vd_${i}
  d.mon stop=cairo
 done

 # stats for annual percentages
 echo "SERIE: ${SERIE}" >> ${SERIE}_summary_stats
 r.univar -t map=`g.list type=raster pattern=${SERIE}_yearly_perc_vd_* sep=,` >> ${SERIE}_summary_stats

 # total count of valid data (sum of yearly counts, more efficient)
 t.rast.series input=${SERIE}_yearly_count_vd \
  output=${SERIE}_total_count_vd method=sum
  
 # total percentage of valid data
 eval `t.info -g input=${SERIE}`
 r.mapcalc expression="${SERIE}_total_perc_vd = (${SERIE}_total_count_vd * 100.0)/$number_of_maps"
 
 # set comparable color tables
 r.colors map=${SERIE}_total_perc_vd \
  rules=$GRASS_FOLDER/my_viridis_no_percentage
 
 # output simple plots
 d.mon start=cairo resolution=1 \
  output=$OUT_FOLDER/${SERIE}_total_perc_vd.png
 d.rast map=${SERIE}_total_perc_vd
 d.legend raster=${SERIE}_total_perc_vd
 d.mon stop=cairo

 # create annual strds of percentages of valid data
 t.create type=strds temporaltype=relative output=${SERIE}_annual_perc_vd \
  title="Percentage of valid data ${SERIE}" \
  description="Yearly percentage of valid data ${SERIE} - 2009-2017"
 t.register input=${SERIE}_annual_perc_vd \
  maps=`g.list type=raster pattern=${SERIE}_yearly_perc_* sep=,` \
  start=1 unit=years increment=1
 
 # annual stats 
 t.rast.univar input=${SERIE}_annual_perc_vd \
  output=$OUT_FOLDER/stats_${SERIE}_annual_perc_vd.csv
  
done

# Remove mask
r.mask -r 


####################################
# GAP-FILLING + overshoot filtering
####################################

# See and run script: gapfill_ghana.sh


#############################################################
# Monthly climatologies based on partially gap-filled series 
# filtered for overshoots
#############################################################

for STRDS in ${SERIES[*]} ; do

 VAR=`echo $STRDS | cut -d'_' -f1`
 
 for MONTH in ${MONTHS[*]} ; do 

  echo "----------- MONTHLY CLIMATOLOGY VAR $VAR, MONTH $MONTH -------------"
  
  t.rast.series input=${STRDS}_lwr_filt method=average \
   where="strftime('%m', start_time)='${MONTH}'" \
   output=${VAR}_lwr_filt_average_climatology_${MONTH}
  
  t.rast.series input=${STRDS}_lwr_filt method=minimum \
   where="strftime('%m', start_time)='${MONTH}'" \
   output=${VAR}_lwr_filt_min_climatology_${MONTH}

  t.rast.series input=${STRDS}_lwr_filt method=maximum \
   where="strftime('%m', start_time)='${MONTH}'" \
   output=${VAR}_lwr_filt_max_climatology_${MONTH}
  
 done

 echo "---------------- STARTING ANIMATION VAR $VAR... ----------------"
 
 # check if some spatial smoothing is needed
 # Note: close the animation, so the script proceeds
 g.gui.animation \
  raster=`g.list rast pat="${VAR}_lwr_filt_average_climatology*" sep=,`
	
done


#######################
# Monthly aggregations
#######################

# set region with res=0:00:30
g.region -p region=ghana

# apply water mask; no need to estimate indices over water bodies
r.mask raster=A2015001_water_mask maskcat=0

# aggregate LST and VI (average, min and max)
for STRDS in ${SERIES[*]} ; do

 STRDS_NEW=`echo $STRDS | cut -d'_' -f1`
 
 g.message message="----------- STARTING AGGREGATIONS FOR $STRDS_NEW..."
 
 for METHOD in ${METHODS[*]} ; do 
			
  t.rast.aggregate input=${STRDS}_lwr_filt \
   output=${STRDS_NEW}_lwr_filt_monthly_${METHOD} \
   basename=${STRDS_NEW}_lwr_filt_${METHOD} \
   suffix=gran granularity="1 months" \
   method=${METHOD}
  
  t.info ${STRDS_NEW}_lwr_filt_monthly_${METHOD}
  
  g.message \
   message="------- DONE MONTHLY AGGREGATION VAR ${STRDS_NEW}, METHOD ${METHOD} -------"	

 done
done

# set region to precip res=0:03
g.region -p align=chirps.v2.0.2009.01.01

# aggregate precip (average and sum)
for PR_METHOD in ${PR_METHODS[*]} ; do

 t.rast.aggregate input=precip_daily \
  output=precip_monthly_${PR_METHOD} basename=precip_${PR_METHOD} \
  suffix=gran granularity="1 months" method=${PR_METHOD}
 
 t.info precip_monthly_${PR_METHOD}
 
 echo "--------- DONE MONTHLY AGGREGATION Precip ${PR_METHOD} -------------"	

done

# aggregate precip (count of days with rain)
t.rast.algebra \
 expression="precip_daily_mask = if(precip_daily > 0, 1, 0)" \
 basename=precip_daily_mask suffix=gran

t.rast.aggregate input=precip_daily_mask output=precip_monthly_count \
 basename=precip_monthly_count method=sum \
 suffix=gran granularity="1 months"

t.info precip_monthly_count

g.message message="----------- DONE MONTHLY Precip COUNT ---------------"


######################################################
# Fill remaining gaps with monthly climatology values
######################################################

for STRDS in ${SERIES[*]} ; do

 if [ "${STRDS}" == "LST.Day_8day" ] || [ "${STRDS}" == "LST.Night_8day" ] ; then
  VAR1=`echo $STRDS | cut -d'_' -f1` ; echo $VAR1
  VAR2=`echo $STRDS | cut -d'_' -f1 | sed -e 's/\./_/g'`; echo $VAR2
 else
  VAR1=`echo $STRDS | cut -d'_' -f1` ; echo $VAR1  
  VAR2=`echo $STRDS | cut -d'_' -f1` ; echo $VAR2
 fi
 
 for YEAR in ${YEARS[*]} ; do
 
  for MONTH in ${MONTHS[*]} ; do
   
   r.mapcalc \
    expression="${VAR2}_average_${YEAR}_${MONTH}_fill = if(isnull(${VAR1}_lwr_filt_average_${YEAR}_${MONTH}), ${VAR1}_lwr_filt_average_climatology_${MONTH}, ${VAR1}_lwr_filt_average_${YEAR}_${MONTH})"
    
   r.mapcalc \
    expression="${VAR2}_maximum_${YEAR}_${MONTH}_fill = if(isnull(${VAR1}_lwr_filt_maximum_${YEAR}_${MONTH}), ${VAR1}_lwr_filt_max_climatology_${MONTH}, ${VAR1}_lwr_filt_maximum_${YEAR}_${MONTH})"
    
   r.mapcalc \
    expression="${VAR2}_minimum_${YEAR}_${MONTH}_fill = if(isnull(${VAR1}_lwr_filt_minimum_${YEAR}_${MONTH}), ${VAR1}_lwr_filt_min_climatology_${MONTH}, ${VAR1}_lwr_filt_minimum_${YEAR}_${MONTH})"
   
  done
  
 done

 # re-build time series
 for METHOD in ${METHODS[*]} ; do
 
  g.list type=raster pattern="${VAR2}_${METHOD}*fill" \
   output=${VAR2}_${METHOD}_fill_maplist 
 
  t.create type=strds temporaltype=absolute output=${VAR2}_monthly_${METHOD}_fill \
   title="Monthly ${METHOD} ${VAR2}" \
   description="Monthly ${METHOD} ${VAR2}. Partially gap-filled with LWR, \
   overshoots filtered and remaining nulls completed with climatology value. \
   Ghana, 2009-2017"
 
  t.register input=${VAR2}_monthly_${METHOD}_fill \
   file=${VAR2}_${METHOD}_fill_maplist \
   start="2009-01-01" increment="1 months"
  
  t.info ${VAR2}_monthly_${METHOD}_fill
  
  rm -f ${VAR2}_${METHOD}_fill_maplist
  
 done
 
done


#####################
# Re-scale variables
#####################

for METHOD in ${METHODS[*]} ; do

 for STRDS in ${SERIES[*]} ; do

  if [ "${STRDS}" == "LST.Day_8day" ] || [ "${STRDS}" == "LST.Night_8day" ] ; then
  
   VAR=`echo $STRDS | cut -d'_' -f1 | sed -e 's/\./_/g'`; echo $VAR
  
   t.rast.algebra basename=${VAR}_monthly_${METHOD} suffix=gran \
    expression="${VAR}_monthly_${METHOD}_scaled = (${VAR}_monthly_${METHOD}_fill * 0.02) - 273.15"

   t.info ${VAR}_monthly_${METHOD}_scaled
 
  else
 
   VAR=`echo $STRDS | cut -d'_' -f1` ; echo $VAR
  
   t.rast.algebra basename=${VAR}_monthly_${METHOD} suffix=gran \
    expression="${VAR}_monthly_${METHOD}_scaled = ${VAR}_monthly_${METHOD}_fill * 0.0001"
   
   t.info ${VAR}_monthly_${METHOD}_scaled
   
  fi
 done
done 


#####################################################
# Zonal statistics and export of vectors and rasters
#####################################################

# Note: Some districts are very small, maybe a change in reg resolution
# is needed for precipitation maps, otherwise polygons might not intersect
# center of cell and hence they will appear as NULL

STRDS=(NDVI_monthly_average_scaled NDVI_monthly_minimum_scaled NDVI_monthly_maximum_scaled
EVI_monthly_average_scaled EVI_monthly_minimum_scaled EVI_monthly_maximum_scaled
NDWI_monthly_average_scaled NDWI_monthly_minimum_scaled NDWI_monthly_maximum_scaled
NDDI_monthly_average_scaled NDDI_monthly_minimum_scaled NDDI_monthly_maximum_scaled
LST_Day_monthly_average_scaled LST_Day_monthly_minimum_scaled LST_Day_monthly_maximum_scaled
LST_Night_monthly_average_scaled LST_Night_monthly_minimum_scaled LST_Night_monthly_maximum_scaled
precip_monthly_average precip_monthly_sum precip_monthly_count)

# set region to 1km res
g.region -p region=ghana

for STRD in ${STRDS[*]} ; do

 # estimate zonal stats and write to attr table
 v.strds.stats input=GHA_districts_clean strds=${STRD} \
  output=GHA_distr_${STRD} method=minimum,maximum,average,stddev
 
 # export vectors (shp) and tables (csv)
 v.out.ogr input=GHA_distr_${STRD} output=GHA_distr_${STRD} \
  format=ESRI_Shapefile
 v.db.select map=GHA_distr_${STRD} file=GHA_distr_${STRD}.csv \
  vertical_separator=comma null_value="*"
 
 # export strds
 t.rast.export input=${STRD} output=${STRD}.tar.gzip \
  directory=$OUT_FOLDER compress=gzip

done


###########
# Cleaning
###########

# remove strds and maps of counts
t.remove -rf ${SERIE}_yearly_count_vd
g.remove -f type=raster pattern="*_total_count_vd*"

# remove precip daily mask
t.remove -rf precip_daily_mask

#~ # remove original bands and QA bands 
#~ t.remove -rf inputs=NIR_reflectance_16day,MIR_reflectance_16day
#~ g.remove type=raster pattern="*[N-M]IR*" -f


exit
