#!/usr/bin/env python
#===============================================================================
#
# Python Numpy/Scipy program for analyzing MMTO WFS seeing data.
#
#===============================================================================

import numpy as np
import matplotlib.cm as cm
import matplotlib.pyplot as plt
import scipy.stats as stats
import MySQLdb
import math
import Image  # PIL library

params = {'axes.labelsize': 14,
          'axes.fontsize' : 14,
          'axes.set_aspect': 14,
          'text.fontsize': 12,
          'legend.fontsize': 14,
          'xtick.labelsize': 14,
          'ytick.labelsize': 14}
plt.rcParams.update(params)

plt.rcParams['figure.figsize'] = 10, 8

# Date for beginning for WFS Data
# t1 = "2003-03-20"

# Date for beginng of wind data from any sensor.
t1 = "2012-05-01"

# Date for starting of temptrax1 background log.
# t1 = "2006-04-18"

# End of study, remains the same...
t2 = "2012-09-01"

w10 = []
w20 = []
w30 = []
w40 = []
w50 = []
w60 = []
w70 = []
w80 = []
w90 = []
w100 = []
w110 = []
w120 = []
w130 = []
w140 = []
w150 = []
w160 = []
w170 = []
w180 = []
w190 = []
w200 = []
w210 = []
w220 = []
w230 = []
w240 = []
w250 = []
w260 = []
w270 = []
w280 = []
w290 = []
w300 = []
w310 = []
w320 = []
w330 = []
w340 = []
w350 = []
w360 = []

# Get the MySQL data.
#
# Reference:
# http://mysql-python.sourceforge.net/MySQLdb.html
db=MySQLdb.connect(user="mmtstaff",passwd="multiple",db="mmtlogs")

# Read in data
c=db.cursor()

# Execute the SQL command to get the seeing data.
# c.execute("""SELECT `timestamp`, `see_zenith_as` FROM `wfs_seeing_log` WHERE timestamp > %s AND timestamp < %s AND (`mode` = "F5" OR `mode` = "F9") ORDER BY `wfs_seeing_log`.`timestamp` ASC""", (t1, t2))
c.execute("""SELECT `timestamp`, `see_zenith_as`, `mode`, MONTH(`timestamp`) FROM `wfs_seeing_log` WHERE timestamp > %s AND timestamp < %s ORDER BY `wfs_seeing_log`.`timestamp` ASC""", (t1, t2))

# Fetch all the rows in a list of lists.
results = c.fetchall()

# A counter of the number of rows returned from the MySQL database.
count = 0

for row in results:
    count += 1
    timestamp = row[0]
    see_zenith_as = row[1]
    wfs_mode = row[2]
    month = row[3]
    
    print "row=%s" % (count,)

    # c.execute("""SELECT timestamp, (cell_frontplate_C - cell_chamber_ambient_C), (cell_chamber_ambient_C - cell_outside_ambient_C) from cell_e_series_background_log WHERE timestamp > %s AND timestamp <= ADDTIME(%s, '00:05:00') ORDER BY `timestamp` ASC LIMIT 1""", (timestamp,timestamp))
    c.execute("""SELECT `timestamp`, `ds_wind_avg_direction` FROM `mount_background_log` WHERE timestamp > %s AND timestamp <= ADDTIME(%s, '00:01:30') ORDER BY `timestamp` ASC LIMIT 1""", (timestamp,timestamp))
    
    results2 = c.fetchall()
    
    
    for row2 in results2:
        # Temperature difference depends on the mode being used.
        # 
        val_param1 = row2[1]  # ds_wind_avg_speed
        
        # print "val_param1=%s" % (val_param1,)
        try:
            max_x = 360.0
            min_x = 0.0
            max_y = 5.0
            min_y = 0.2
            
            for row2 in results2:
                # 
                val_param1 = row2[1]  # `ds_wind_avg_speed
                try:
                    # Checking that numbers are floats.
                    if float(val_param1):                
                        if val_param1 >= min_x:
                            if val_param1 <= max_x:
                                if see_zenith_as >= min_y:
                                    if see_zenith_as <= max_y:
                                        wind = val_param1
                                        if wind < 10:
                                            w10.append(see_zenith_as)
                                        elif wind < 20:
                                            w20.append(see_zenith_as)
                                        elif wind < 20:
                                            w20.append(see_zenith_as)
                                        elif wind < 30:
                                            w30.append(see_zenith_as)
                                        elif wind < 40:
                                            w40.append(see_zenith_as)
                                        elif wind < 50:
                                            w50.append(see_zenith_as)
                                        elif wind < 60:
                                            w60.append(see_zenith_as)
                                        elif wind < 70:
                                            w70.append(see_zenith_as)
                                        elif wind < 80:
                                            w80.append(see_zenith_as)
                                        elif wind < 90:
                                            w90.append(see_zenith_as)
                                        elif wind < 100:
                                            w100.append(see_zenith_as)
                                        elif wind < 110:
                                            w110.append(see_zenith_as)
                                        elif wind < 120:
                                            w120.append(see_zenith_as)
                                        elif wind < 130:
                                            w130.append(see_zenith_as)
                                        elif wind < 140:
                                            w140.append(see_zenith_as)
                                        elif wind < 150:
                                            w150.append(see_zenith_as)
                                        elif wind < 160:
                                            w160.append(see_zenith_as)
                                        elif wind < 170:
                                            w170.append(see_zenith_as)
                                        elif wind < 180:
                                            w180.append(see_zenith_as)
                                        elif wind < 190:
                                            w190.append(see_zenith_as)
                                        elif wind < 200:
                                            w200.append(see_zenith_as)
                                        elif wind < 210:
                                            w210.append(see_zenith_as)
                                        elif wind < 220:
                                            w220.append(see_zenith_as)
                                        elif wind < 230:
                                            w230.append(see_zenith_as)
                                        elif wind < 240:
                                            w240.append(see_zenith_as)
                                        elif wind < 250:
                                            w250.append(see_zenith_as)
                                        elif wind < 260:
                                            w260.append(see_zenith_as)
                                        elif wind < 270:
                                            w270.append(see_zenith_as)
                                        elif wind < 280:
                                            w280.append(see_zenith_as)
                                        elif wind < 290:
                                            w290.append(see_zenith_as)
                                        elif wind < 300:
                                            w300.append(see_zenith_as)
                                        elif wind < 310:
                                            w310.append(see_zenith_as)
                                        elif wind < 320:
                                            w320.append(see_zenith_as)
                                        elif wind < 330:
                                            w330.append(see_zenith_as)
                                        elif wind < 340:
                                            w340.append(see_zenith_as)
                                        elif wind < 350:
                                            w350.append(see_zenith_as)
                                        else:
                                            w360.append(see_zenith_as)

                                        print "Count %s, Adding %s" % (count, val_param1)
                                        
                                        
                except:
                    print "Error: Bad data"    
        except:
            print "Error: Data out of range."


title_str = """Seeing Histogram: %s to %s""" % (t1, t2)
xlabel_str = 'Wind Direction (Degrees East of North)'
ylabel_str = 'Median Seeing (arc-seconds) (Corrected to Zenith)'

# disconnect from server
db.close()


#print "Size np1 = %s" % (len(wind_all))
#print "Median np1 =  %s" % (np.ma.extras.median(np1))
#print "Mean np1 =  %s" % (np1.mean())

#txt =  "Wind (<2 m/s) Statistics:\n"
#txt += "  Samples = %s\n" % (len(wind_all))
#txt += "  Median =  %.2f arc-sec\n" % (np.ma.extras.median(np1))

bins_x = 36

np10 = np.array(w10)
np20 = np.array(w20)
np30 = np.array(w30)
np40 = np.array(w40)
np50 = np.array(w50)
np60 = np.array(w60)
np70 = np.array(w70)
np80 = np.array(w80)
np90 = np.array(w90)
np100 = np.array(w100)
np110 = np.array(w110)
np120 = np.array(w120)
np130 = np.array(w130)
np140 = np.array(w140)
np150 = np.array(w150)
np160 = np.array(w160)
np170 = np.array(w170)
np180 = np.array(w180)
np190 = np.array(w190)
np200 = np.array(w200)
np210 = np.array(w210)
np220 = np.array(w220)
np230 = np.array(w230)
np240 = np.array(w240)
np250 = np.array(w250)
np260 = np.array(w260)
np270 = np.array(w270)
np280 = np.array(w280)
np290 = np.array(w290)
np300 = np.array(w300)
np310 = np.array(w310)
np320 = np.array(w320)
np330 = np.array(w330)
np340 = np.array(w340)
np350 = np.array(w350)
np360 = np.array(w360)

N = 36
ind = np.arange(N)    # the x locations for the groups
width = 0.2       # the width of the bars: can also be len(x) sequence

plt.bar( ind, [ np.ma.extras.median(np10), np.ma.extras.median(np20), np.ma.extras.median(np30), np.ma.extras.median(np40), np.ma.extras.median(np50), np.ma.extras.median(np60), np.ma.extras.median(np70), np.ma.extras.median(np80), np.ma.extras.median(np90), np.ma.extras.median(np100), np.ma.extras.median(np110), np.ma.extras.median(np120), np.ma.extras.median(np130), np.ma.extras.median(np140), np.ma.extras.median(np150), np.ma.extras.median(np160), np.ma.extras.median(np170), np.ma.extras.median(np180), np.ma.extras.median(np190), np.ma.extras.median(np200), np.ma.extras.median(np210), np.ma.extras.median(np220), np.ma.extras.median(np230), np.ma.extras.median(np240), np.ma.extras.median(np250), np.ma.extras.median(np260), np.ma.extras.median(np270), np.ma.extras.median(np280), np.ma.extras.median(np290), np.ma.extras.median(np300), np.ma.extras.median(np310), np.ma.extras.median(np320), np.ma.extras.median(np330), np.ma.extras.median(np340), np.ma.extras.median(np350), np.ma.extras.median(np360) ], width )


plt.legend()

#plt.text(2.25, 5000, txt,
#        horizontalalignment='left',
#        verticalalignment='top')

plt.title(title_str, fontsize=18)
plt.xlabel(xlabel_str, fontsize=14)
plt.ylabel(ylabel_str, fontsize=14)

plt.xticks(ind+width/2., ('5', '15', '25', '35', '45', '55', '65', '75', '85', '95', '105', '115', '125', '135', '145', '155', '165', '175', '185', '195', '205', '215', '225', '235', '245', '255', '265', '275', '285', '295', '305', '315', '325', '335', '345', '355'), rotation=90, size='small' )

plt.grid(True)

plt.axis('tight')

show = False
if show:
    plt.show()
else:     
    plt.savefig("trisum_seeing_wind_direction.png");




