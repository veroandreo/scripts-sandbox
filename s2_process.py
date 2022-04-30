#!/usr/bin/env python3
# -*- coding: utf-8 -*-

########################################################################
# Script para bajar y procesar Sentinel 2
# Autor: Veronica Andreo
# Fecha: Abril, 2020
########################################################################

## Requires:
# an account in https://scihub.copernicus.eu/dhus/#/home,
# a file with username and password called sentinel in $HOME,
# grass-session, sentinelsat and pandas libraries,
# grass gis 7.8+
# grass gis add-on: i.sentinel

## ATENTION! This must be ran only one time, then comment out and
## run script as described under `Usage`

#~ # 0. Create an utm21s location and sentinel2 mapset
#~ grass78 -c EPSG:32721 $HOME/grassdata/utm20s
#~ g.mapset -c mapset=sentinel2
#~ g.extension extension=i.sentinel

# Usage:
#         'export GRASSBIN=grass78 ; python s2_process.py'


# general use libraries
import os
import shutil
import datetime
import zipfile
from pathlib import Path
from osgeo import gdal

# open GRASS
from grass_session import Session

# import grass python libraries
import grass.script as gscript

from grass.pygrass.modules.shortcuts import general as g
from grass.pygrass.modules.shortcuts import raster as r
from grass.pygrass.modules.shortcuts import vector as v
from grass.pygrass.modules.shortcuts import imagery as i
from grass.pygrass.modules.shortcuts import temporal as t


# directories' names
home_path = '/home/veroandreo/'
inDir = home_path+'Documents/fms/bid/data/' # downloaded scenes
outDir = home_path+'Documents/fms/bid/out/' # final outputs

# file names
s2_setting_file = home_path+'sentinel'
last_processed_date = outDir+'s2_last_proc_date'

# grass variables
os.environ['GRASS_OVERWRITE'] = '1'
os.environ['GRASS_COMPRESS_NULLS'] = '1'
os.environ['GRASS_COMPRESSOR'] = 'ZSTD'

# location/mapset
mygisdb = home_path+'grassdata'
mylocation = 'utm20s'
mymapset = 'sentinel2'

# range of dates to search S2 scenes
end_date = '2022-02-01' # datetime.date.today()
start_date = '2021-12-01' # end_date - datetime.timedelta(30)

# bounding box Tartagal in UTM 20S
n=7540132
w=385079
e=451369
s=7475082


# create target directories if they don't exist
for dirname in [inDir,outDir]:
    if not os.path.exists(dirname):
        os.makedirs(dirname)
        print('Directory {} created'.format(dirname))
    else:
        print('Directory {} already exists'.format(dirname))


# start a GRASS session in mymapset
user = Session()
user.open(gisdb=mygisdb, location=mylocation, mapset=mymapset)


#
# PROCESSING
#


# define region of interest
gscript.run_command('g.region', n=n, w=w, e=e, s=s, flags='p')

# list S2 available scenes
list_s2 = gscript.read_command("i.sentinel.download",
                               flags='l',
                               settings=s2_setting_file,
                               output=inDir,
                               area_relation='Intersects',
                               clouds=30,
                               producttype='S2MSI2A',
                               start=start_date,
                               end=end_date,
                               sort='ingestiondate',
                               order='desc')

# parse uuid to download and most recent date
uuid = list_s2.split()[0]
print(uuid)
date_download = list_s2.split()[2].split('T')[0]
print(date_download)

# check if date was already processed
while True:

    try:

        os.path.exists(last_processed_date)
        file = open(last_processed_date, 'r+')  # open in read+write mode

    except FileNotFoundError:

        print('File does not exist. \n No S2 data have been processed yet')
        print('Proceeding to download and process S2 data for date: {}'.format(date_download))

        gscript.run_command("i.sentinel.download",
                            settings=s2_setting_file,
                            output=inDir,
                            uuid=uuid,
                            sleep=30)

        file = open(last_processed_date, 'w')  # open in write mode
        file.write(date_download)
        file.close()

    else:

        if len(uuid) == 1 and file.read(10) != date_download:

            # download S2 scene
            print('Proceeding to download and process S2 data for date: {}'.format(date_download))
            gscript.run_command("i.sentinel.download",
                                settings=s2_setting_file,
                                output=inDir,
                                uuid=uuid,
                                sleep=30)

            # write new date processed to file
            file.seek(0)
            file.truncate()
            file.write(date_download)
            file.close()

        else:

            print('No new S2 scene to process')
            file.close()
            break


## ACA FALTARIA UNA CONDICION PARA QUE NO LAS IMPORTE SI 
## YA ESTAN PROCESADAS O PONER LA IMPORTACION MAS ARRIBA, 
## o que salga mas elegantemente


# importing bands
print('Importing S2 bands into GRASS GIS...')

gscript.run_command('i.sentinel.import',
                    input=inDir,
                    pattern='B(02_1|03_1|04_1|08_1|8A_2|11_2|12_2)0m',
                    extent='input',
                    memory='500',
                    flags='j')

# bands
blue = gscript.list_strings(type='raster', pattern='*B02_1*', exclude='*_double', mapset='.')
green = gscript.list_strings(type='raster', pattern='*B03_1*', exclude='*_double', mapset='.')
red = gscript.list_strings(type='raster', pattern='*B04_1*', exclude='*_double', mapset='.')
nir = gscript.list_strings(type='raster', pattern='*B08_1*', exclude='*_double', mapset='.')
nir8a = gscript.list_strings(type='raster', pattern='*B8A_2*', exclude='*_double', mapset='.')
swir11 = gscript.list_strings(type='raster', pattern='*B11_2*', exclude='*_double', mapset='.')
swir12 = gscript.list_strings(type='raster', pattern='*B12_2*', exclude='*_double', mapset='.')

# define region to the full scene
gscript.run_command('g.region', raster=blue, flags='p')

# ~ #unzip S2 scene - needed to search for the MTD file (as of Apr 18, 2022 nor json neither mtd metadata works)
# ~ files = os.listdir(inDir)
# ~ zip_file = [i for i in files if i.endswith('.zip')] # get a list
# ~ zip_file = ''.join([str(i) for i in zip_file]) # need a string
# ~ zip_dir = inDir+zip_file # need the path to the zip file

# ~ with zipfile.ZipFile(zip_dir, 'r') as to_unzip:
    # ~ to_unzip.extractall(inDir)
    # ~ print('S2 file unzipped!')

# ~ # find metadata file (must be unzipped for this to work)
# ~ for path in Path(inDir).rglob('MTD_TL.xml'):
    # ~ mtd_file = path

# cloud and cloud shadow detection
print('Starting cloud and cloud shadow detection')

gscript.run_command('i.sentinel.mask',
                    flags='s',
                    blue=blue,
                    green=green,
                    red=red,
                    swir11=swir11,
                    nir=nir,
                    swir12=swir12,
                    nir8a=nir8a,
                    cloud_mask='cloud_mask',
                    shadow_mask='shadow_mask',
                    scale_fac='10000')

# list output clouds and shadows maks
masks = gscript.list_strings(type='vector',
                             pattern="*_mask",
                             exclude='s2*',
                             mapset=mymapset)

# estimate ndvi and ndwi

# formulas
ndvi_formula = "s2_ndvi = round(if($red > 10000 && $nir > 10000, 10000, if($red <= 10000 && $nir <= 10000, float($nir - $red) / float($nir + $red))*10000))"
ndwi_formula = "s2_ndwi = round(if($green > 10000 && $nir > 10000, 10000, if($green <= 10000 && $nir <= 10000, float($nir - $green) / float($nir + $green))*10000))"

red = red[0].split('@')[0]
nir = nir[0].split('@')[0]
green = green[0].split('@')[0]
blue = blue[0].split('@')[0]

if len(masks) == 0:

    print('No clouds or shadows detected, no mask to be set')

    print('Estimating NDVI and NDWI...')

    gscript.raster.mapcalc(ndvi_formula,
                           nir = nir,
                           red = red)
    gscript.raster.mapcalc(ndwi_formula,
                           green = green,
                           nir = nir)

elif len(masks) == 1:

    print('Only {} detected, using it as mask'.format(masks[0].split('@')[0]))

    # set mask
    r.mask(flags='i',
           vector=masks[0].split('@')[0])

    print('Estimating NDVI and NDWI...')

    gscript.raster.mapcalc(ndvi_formula)
    gscript.raster.mapcalc(ndwi_formula)

else:

    print('Both {} and {} detected, patching and setting mask'.format(masks[0].split('@')[0],masks[1].split('@')[0]))

    # patch cloud and shadow vectors and set mask
    v.patch(input=masks,
            output='s2_mask')
    r.mask(flags='i',
           vector='s2_mask')

    print('Estimating NDVI and NDWI...')

    gscript.raster.mapcalc(ndvi_formula,
                           nir = nir,
                           red = red)
    gscript.raster.mapcalc(ndwi_formula,
                           green = green,
                           nir = nir)


# ~ # create RGB group
# ~ i.group(group='s2_rgb',
        # ~ input=[red,green,blue])

# ~ print("Exporting RGB, NDVI and NDWI maps...")

# ~ # export RGB as 3 band tif, NDVI and NDWI
# ~ r.out_gdal(input='s2_rgb',
           # ~ output =inDir+'s2_rgb.tif',
           # ~ format_='GTiff',
           # ~ createopt="PROFILE=GeoTIFF,INTERLEAVE=PIXEL,TFW=YES")
# ~ r.out_gdal(input='s2_ndvi',
           # ~ output=inDir+'s2_ndvi.tif',
           # ~ format_='GTiff')
# ~ r.out_gdal(input='s2_ndwi',
           # ~ output=inDir+'s2_ndwi.tif',
           # ~ format_='GTiff')

# check if MASK is set
mask_set = gscript.list_strings(type='raster',
                                pattern="*MASK*")

if len(mask_set) > 0:

    print('Removing MASK...')
    r.mask(flags='r')

else:
    print('No MASK set, nothing to do')


# using GDAL to re-project from UTM to 4326
# print('Re-projecting outputs to EPSG:4326...')
#
# for path in Path(inDir).rglob('*.tif'):
#     tiff = path
#     ds = gdal.Open(str(tiff))
#     print(os.path.basename(ds))
#
    # if os.path.basename(ds) == 's2_rgb.tif':
    #     options_rgb = gdal.WarpOptions(srcSRS='EPSG:32721',
    #                                    dstSRS='EPSG:4326',
    #                                    dstNodata='65535')
    #     gdal.Warp(destNameOrDestDS=outDir+ds+date_download+'.tif',
    #               srcDSOrSrcDSTab=inDir+ds,
    #               options=options_rgb)
    #     ds=None
    # else:
    #     options_single_raster = gdal.WarpOptions(srcSRS='EPSG:32721',
    #                                              dstSRS='EPSG:4326',
    #                                              dstNodata='-32768')
    #     gdal.Warp(destNameOrDestDS=outDir+ds.upper()+date_download+'.tif',
    #               srcDSOrSrcDSTab=inDir+ds,
    #               options=options_single_raster)
    #     ds=None

#
# Cleanup
#

# print("Cleaning up {} and removing {}".format(mymapset,inDir))

# clean mapset
# g.remove(type=['raster','vector','group'], flags='f')

# remove s2 folder with downloaded files
# shutil.rmtree(inDir)

# exit from user session
print("Closing GRASS GIS... bye!")

user.close()

