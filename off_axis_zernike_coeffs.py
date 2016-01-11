#!/usr/bin/python

#This piece of code uses a table of off-axis zernike values
#for MMIRS that BcLeod made from Zmax.
#inputs are the radial distance (in arcsec)

import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy import interpolate

if len(sys.argv) < 2 :
    print("off_axis_zernike_coeffs.py dist(arcsec)")
    sys.exit(2)

rad = sys.argv[1]

#Convert the distance to degrees
dist = np.abs(float(rad) / 3600.0)

zern_file = '/mmt/shwfs/mmirszernfield.tab'
cols = np.loadtxt(zern_file, skiprows=2)
output = []

for ii in range(1, 12):

    x = cols[:,0]
    y = cols[:,ii]
    f = interpolate.interp1d(x, y)
    ynew = f(dist)
    output.append(float(ynew))

print(' '.join(map(str, output)))
    
    
