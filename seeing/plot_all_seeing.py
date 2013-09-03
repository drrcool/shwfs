#!/usr/bin/env python
#===============================================================================
#
# Plot CO2 data collected off Cape Point
#
# Marjolaine Rouault: mrouault@csir.co.za
#===============================================================================

from pylab import *
from datetime import datetime
from courseFunctions import readCo2
from matplotlib.dates import YearLocator, MonthLocator, DateFormatter
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas

# Path and file name definition
pname = ''
fname = 'CPT_CO2_dm_95_07.txt'

# Read in data
time, x, y = readCo2(pname+fname) 

# Start and end time definition for x-axis
time_start=matplotlib.dates.date2num(datetime(1995,1,1))
time_end=matplotlib.dates.date2num(datetime(2007,12,31))
# Format definition for x-axis
years = YearLocator() # every year
months = MonthLocator() # every month
dateFmt = DateFormatter('%Y')

st = matplotlib.dates.date2num(datetime(1950,1,1))
plotDate=matplotlib.dates.num2date(time+st)

fig = figure(figsize =(12., 5.),facecolor='white', edgecolor='black')
ax = fig.add_axes([0.05, 0.1, 0.85, 0.8],axisbg='white')
ax.plot_date(plotDate,x, 'gray',linewidth = 1.0)
ax.plot_date(plotDate,y, 'k',linewidth = 1.5)
ax.set_xlim( time_start, time_end)
# format the ticks
ax.xaxis.set_minor_locator(months)
ax.xaxis.set_major_locator(years)
ax.xaxis.set_major_formatter(dateFmt)
ax.xaxis.grid(True,'minor',linewidth=1)
ax.xaxis.grid(True,'major',linewidth=1,linestyle='-')
xticks(size=9)
yticks(size=9)
ylabel('concentration',fontsize=10)
xlabel('Time')
title('Fluctuation of CO2 with time')
show()

canvas = FigureCanvas(fig)
canvas.print_figure('co2_series.png',dpi=100)
