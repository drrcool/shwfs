#!/usr/bin/python

#This piece of code will take the residual files output by getZernikeModesandPhases and make some
#informative plots about them..

import os
import sys
import matplotlib.pyplot as plt
from pylab import rcParams
import numpy as np


def read_cntr_file(filename):

    f = open(filename, 'r')
    data = []

    for line in f:
        if line[0] != '#':
            line = line.strip()
            columns = line.split()
            source = {}
            source['x'] = columns[0]
            source['y'] = columns[1]
            data.append(source)
    f.close()
    return data



fitsfile = sys.argv[1]
mode = sys.argv[2]

if mode == "MMIRS":
    pix_scale = 0.16  # pixel scale
    plotrange = 150
elif mode == "F9":
    pix_scale = 0.12
    plotrange = 200
elif mode == "F5":
    pix_scale = 0.135
    plotrange = 220
    
root = fitsfile.split('.')[0]
outfile = root + '_resid.png'
outxpm = 'resid.png'

#First lets do the matched files
sysfile = 'sys_dim.cntr'
stelfile = 'stel_dim.cntr'

sysdata = read_cntr_file(sysfile)
steldata = read_cntr_file(stelfile)

x0 = []
x1 = []
y0 = []
y1 = []
dist = []


scale = 3.0

if len(sysdata) > 0 :
    for ii in range(0,len(sysdata)-1):
        x0.append(sysdata[ii]['x'])
        y0.append(sysdata[ii]['y'])
        
        xdist = float(sysdata[ii]['x'])-float(steldata[ii]['x'])
        ydist = float(sysdata[ii]['y'])-float(steldata[ii]['y'])
        
        x1.append(float(sysdata[ii]['x'])-xdist*scale)
        y1.append(float(sysdata[ii]['y'])-ydist*scale)
        
        dist.append( (float(sysdata[ii]['x'])-float(steldata[ii]['x']))**2 +
                     (float(sysdata[ii]['y'])-float(steldata[ii]['y']))**2)
        
        dist_rms = np.sqrt( np.mean( np.square(dist)))*pix_scale
        
        
    rcParams['figure.figsize'] = 4., 4.
    rcParams.update({'font.size':6})
    
    
    
    for ii in range(0,len(x0)-1):
        plt.plot( [x0[ii],x1[ii]],
                  [y0[ii],y1[ii]], 'b')
        
    plt.text(-0.9*plotrange, 0.9*plotrange, "Mag="+str(scale), fontsize=10)
    plt.text(-0.9*plotrange,-0.9*plotrange, 'RMS= %2.2f"' % dist_rms, fontsize=10)
    plt.xlim(xmin=-1*plotrange, xmax=plotrange)
    plt.ylim(ymin=-1*plotrange, ymax=plotrange)
    plt.savefig(outxpm)

