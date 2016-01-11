#!/usr/bin/python

#This piece of code will take the residual files output by getZernikeModesandPhases and make some
#informative plots about them..

import matplotlib.pyplot as plt
import numpy as np

def read_cntr_file(filename):

    f = open(filename, 'r')
    x = []
    y = []

    for line in f:
        if line[0] != '#':
            line = line.strip()
            columns = line.split()
            x1 = columns[0]
            y1 = columns[1]
            x.append(x1)
            y.append(y1)
    f.close()
    return x, y

#First lets do the matched files
sysfile = 'sys_dim.cntr'
stelfile = 'stest1.cntr'

sys_x, sys_y = read_cntr_file(sysfile)
full_x, full_y = read_cntr_file(stelfile)





plt.plot(full_x, full_y, 'b.')
plt.plot(sys_x, sys_y, 'r.')
plt.xlabel('X Offset (pixel)')
plt.ylabel('Y Offset (pixel)')

plt.xlim(xmin=-200, xmax=200)
plt.ylim(ymin=-150, ymax=150)

plt.show()
