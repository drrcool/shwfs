#!/usr/bin/python
import os
import shutil
import time

#Get a list of all the fits files in the original directory. 
indir = '/home/rcool/datadir/'
targetdir = '/mmt/shwfs/datadir/'
infiles = os.listdir(indir)
fitsfiles = []

for file in infiles:
    if file.endswith('.fits'):
        fitsfiles.append(indir +  file)

filecount = 0
for file in fitsfiles:
    shutil.copy(file, targetdir)
    print("Copied file " + file)
    text_file = open(targetdir + 'mmirs-pipe.log', 'w')
    text_file.write(file + '\n')
    text_file.write(str(time.time()))
    text_file.close()
    time.sleep(10)

