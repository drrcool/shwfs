#This nice little piece of code will take three inputs guideX, guideY, the 
#x and y postion of the MMIRS guider cameras (in mm), and rotator, the
#angle that the rotator is currently at to translate the coordinates to 
#those on the focal plane of the MMT.  These then get translated to 
#degress and returned.

import numpy
import sys
from math import * 



def transform_mmirs_coord(guideX, guideY, rot):
    #First we have to convert these to polar coordinates. NOTE THAT
    #PHI IS THE ANGLE FROM Y AS THIS IS HOW THETA IS DEFINED FOR THE MMT.
    
    guiderR = sqrt(guideX**2 + guideY**2)
    if guideY != 0:
        guiderPhi = atan(guideX/guideY)
    else :
        guiderPhi = radians(90.)
    
    #Transform the radius to degrees
    focalR = 0.0016922*guiderR - 4.60789e-9*guiderR**3 - 8.111307e-14*guiderR**5
    focalPhi = guiderPhi + radians(rot)
    
    #Now go back to focal plane X,Y
    focalX = focalR * sin(focalPhi)
    focalY = focalR * cos(focalPhi)
    
    return focalX, focalY
    
    
def main(argv):
    
    guideX = float(argv[1])
    guideY = float(argv[2])
    rot = float(argv[3])

    print(transform_mmirs_coord(guideX, guideY, rot))

if __name__ == '__main__':
    main(sys.argv)