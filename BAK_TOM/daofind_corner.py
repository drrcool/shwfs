#!/usr/bin/env python

import sys
import getopt
from numpy.numarray import *
import scipy.ndimage as nd
import scipy
import pyfits
import imagestats

def dimm_seeing(fwhm, ref_fwhm, scale):

    # this is the eff wavelength of both systems
    lamb = 0.65e-6

    # 14 apertures/pupil is also pretty close for both cases
    # certainly for f/5 while f/9 is a little funky with the hex geom
    d = 6.5/14.0

    # reference files give me a mean fwhm of about 2.1-2.15 pix
    if fwhm > ref_fwhm:
        #
        # deconvolve reference fwhm and convert to radians.
        #
        f = sqrt(2.0)*sqrt(fwhm**2 - ref_fwhm**2)*scale/206265.0
        s = (f**2)/(8*log(2))

        r0 = ( 0.358*(lamb**2)*(d**(-1.0/3.0))/s )**0.6
        seeing = 206265*0.98*lamb/r0
        return seeing
    else:
        return 0.0

def ds9spots(file, xcol, ycol, color):
    data = file.split('\.')
    reg = data[0] + ".reg"
    xpa = open(reg, 'w')
    xpa.write("# Region file format: DS9 version 3.0\n")
    xpa.write("# Filename: %s\n" % file)
    xpa.write("global color=%s font=\"helvetica 10 normal\" select=1 edit=1 move=1 delete=1 include=1 fixed=0 source\n" % color)
    
    spots = open(file, 'r')
    for line in spots:
        data = line.split()
        x = data[xcol]
        y = data[ycol]
        xpa.write("image;circle(%f,%f,1) # color = %s\n" % (float(x), float(y), color))

    xpa.close()
    os.system("cat %s | xpaset WFS regions" % reg)

def rfits(file):
    f = pyfits.open(file)
    hdu = f[0]
    (im, hdr) = (hdu.data, hdu.header)
    f.close()
    return hdu

def get_seeing(file, scale, ref):
    coords = file.replace('fits','dao')
    log = file.replace('fits','psf')
    out = file.replace('fits','seeing')
    
    pipe = os.popen("/mmt/shwfs/psfmeasure psfmeasure %s coords=\"markall\" wcs=\"logical\" display=no frame=1 level=0.5 size=\"FWHM\" radius=10.0 sbuffer=1.0 swidth=3.0 iterations=1 logfile=\"%s\" imagecur=\"%s\" graphcur=\"/mmt/shwfs/end\" | grep Average | awk '{print $9}'" % (file, log, coords))

    fwhm = pipe.read()
    if fwhm:
        fwhm_pix = float(fwhm)
        fwhm = fwhm_pix*scale
        seeing = dimm_seeing(fwhm_pix, ref, scale)
        fp = open(out, 'w')
        fp.write("%f %f\n" % (fwhm_pix, seeing))
        fp.close()
        os.system("echo \"image;text 85 500 # text={Spot FWHM = %5.2f pixels}\" | xpaset WFS regions" % fwhm_pix)
        os.system("echo \'image;text 460 500 # text={Seeing = %4.2f\"}\' | xpaset WFS regions" % seeing)
#        os.system("/mmt/shwfs/set_seeing.rb %4.2f" % seeing)
#        os.system("echo \"set wfs_seeing %4.2f\" | nc hacksaw 7666" % seeing)

def get_center(im, xrefcen, yrefcen):
    (ycen, xcen) = nd.center_of_mass(im)
    #(ycen, xcen) = pos[0]
    xcen = xcen+1
    #ycen = ydim-ycen+1
    ycen = ycen+1
    
#    print "Pupil Center: X = %7.3f, Y = %7.3f" % (xcen, ycen)
#    os.system("echo \"circle %f %f 5 # color=yellow\" | xpaset WFS regions" % (xcen, ycen))
    xoff = xcen - xrefcen
    yoff = ycen - yrefcen
#    print "Pupil Offset: X = %7.3f, Y = %7.3f" % (xoff, yoff)
#    print "                  %6.2f\",     %6.2f\"" % (xoff*scale[mode]/sky[mode], yoff*scale[mode]/sky[mode])

    return (xcen, ycen)

def daofind(image):
    cfile = open("/mmt/shwfs/%s_reference.center" % mode, 'r')
    [xrefcen, yrefcen] = cfile.read().split()
    xrefcen = float(xrefcen)
    yrefcen = float(yrefcen)
    cfile.close

    ffile = open("/mmt/shwfs/%s_reference.fwhm" % mode, 'r')
    [reffwhm, reffwhm_pix] = ffile.read().split()
    reffwhm = float(reffwhm)
    reffwhm_pix = float(reffwhm_pix)
    ffile.close
    im = image 

    corner1 = scipy.concatenate((im[5:105,5:105], im[405:505,5:105]))
    corner2 = scipy.concatenate((im[405:505,405:505], im[5:105,405:505]))
    cat = scipy.concatenate((corner1, corner2))
    cornerstats = imagestats.ImageStats(cat)
    corner = cornerstats.mean
    corner_sig = cornerstats.stddev

    print "Corner mean = ", corner
    print "Corner sig = ", corner_sig
    
    im = im - corner
    allstats = imagestats.ImageStats(im)
    stats = imagestats.ImageStats(im, nclip=5)
    mean = stats.mean - corner
    sig = stats.stddev
    max = stats.max

    print "Mean = ", mean
    
    if mode == 'F9':
        smooth = nd.gaussian_filter(im, 5.0)
    else:
        smooth = nd.gaussian_filter(im, 3.0)
        
    nsig = 5.0
    nstars = 0

    while nstars < 140:
        spot_clip = smooth >= (nsig*sig)
        labels, num = nd.label(spot_clip)
        nstars = num
        nsig = nsig - 0.2
        if nsig <= 0.0:
            break
#        print num, " spots found."

    if num < 140:
        print "Pupil too far off image or seeing too poor."
        os.system("echo \"image;text 256 500 # text={Seeing too poor or pupil too far off image.}\" | xpaset WFS regions")
        return (False, False, False)
    
    if mode == 'F9':
        clip = smooth >= ((nsig+2.0)*sig)
    else:
        clip = smooth >= ((nsig-2.0)*sig)

    pos = nd.center_of_mass(im, labels, range(num))
    counts = nd.sum(im, labels, range(num))
    countstats = imagestats.ImageStats(counts, nclip=3)
    cmean = countstats.mean
    csig = countstats.stddev

    daofile = fitsfile.replace('fits', 'dao')
    dao = open(daofile, 'w')

    spots = []
  
    for spot in pos[1:]:
        (y, x) = spot
        x = x + 1
        y = y + 1
        i = pos.index(spot)
        c = counts[i]
        spots.append( (x, y, c) )
        dao.write("%8.3f  %8.3f\n" % (x, y))
        
    dao.close()
    
    ds9spots(daofile, 0, 1, 'red')

    cen_clip = nd.gaussian_filter(im, 10.0) >= 15*corner_sig
    
    (xcen, ycen) = get_center(cen_clip, xrefcen, yrefcen)
    get_seeing(fitsfile, scale[mode], reffwhm_pix)

    cenfile = fitsfile.replace('fits', 'center')
    cen = open(cenfile, 'w')
    cen.write("%f %f\n" % (xcen, ycen))
    cen.close()
    return (xcen, ycen, spots)

def average(fitsfiles):
    if fitsfiles.find(',') > -1:
        files = fitsfiles.split(',')
        averot = 0.0
        for file in files:
            hdu = rfits(file)
            im = hdu.data
            hdr = hdu.header
            try:
                rot = hdr['ROT']
            except KeyError:
                rot = 0.0

            averot = averot + float(rot)
            
            try:
                ave
            except NameError:
                ave = None

            if ave is None:
                ave = im/len(files)
            else:
                ave = ave + im/len(files)

        ave = ave/len(files)
        try:
            hdr['ROT'] = averot/len(files)
        except KeyError:
            hdr.add_history("Rotator angle not available.")
        hdr.add_history("Averaged %s." % fitsfiles)
        out = file.replace('.fits', '_ave.fits')
        hdu.data = ave
        hdu.header = hdr
        try:
            hdu.writeto(out)
        except:
            os.remove(out)
            hdu.writeto(out)
            
        return(out)
    else:
        return fitsfiles

# need this for f/9.....
def getmags():
    fp = open("xyrc.tst", 'r')
    lines = fp.readlines()
    fp.close

    spots = []
    nr = 0
    nc = 0
    for line in lines:
        data = line.split()
        x = float(data[0])
        y = float(data[1])
        row = int(float(data[2]))
        col = int(float(data[3]))
        spots.append([x,y,row,col])
        if row > nr:
            nr = row
        if col > nc:
            nc = col

    rows = []
    cols = []
    for i in range(0,nr+1):
        rows.append([])
    for i in range(0,nc+1):
        cols.append([])

    for spot in spots:
        rows[spot[2]].append(spot[1])
        cols[spot[3]].append(spot[0])

    nyave = 0
    yave = 0
    for row in rows:
        row.sort()
        if len(row) > 3:
            for i in range(0,len(row)-1):
                diff = row[i+1] - row[i]
                if diff < 50.0:
                    yave = yave + diff
                    nyave = nyave + 1

    # correct for hexagonal array
    yave = (25.0/26.0)*(1.732/2.0)*yave/nyave

    nxave = 0
    xave = 0
    for col in cols:
        col.sort()
        if len(col) > 3:
            for i in range(0,len(col)-1):
                diff = abs(col[i+1] - col[i])
                if diff < 75.0:
                    xave = xave + diff
                    nxave = nxave + 1

    # correct for hexagonal array
    xave = (12.0/13.0)*xave/(2.0*nxave)
    return (xave, yave)
    
def shcenfind(fitsfile, mode, xcen, ycen):
    if mode == 'F9':
        pipe = os.popen("/mmt/shwfs/shcenfind %s" % fitsfile.replace('fits', 'dao'))
    else:
        pipe = os.popen("/mmt/shwfs/shcenfind_f5 %s" % fitsfile.replace('fits', 'dao'))

    rows, cols = pipe.read().split()
    print "Found %s rows and %s cols." % (rows, cols)
    
    dao = open(fitsfile.replace('fits', 'dao'), 'r')
    daolines = dao.readlines()
    dao.close()

    (dum1, dum2, xmag, ymag, xc, yc) = daolines[0].split(' ')
    if mode == 'F9':
        if rows == '26' and cols == '13':
            daolines[0] = "# X %s %s %s %s" % (xmag, ymag, xc, yc)
            os.system("echo \"circle %f %f 5 # color=yellow\" | xpaset WFS regions" % (float(xc), float(yc)))
        else:
            (xmag, ymag) = getmags()
            daolines[0] = "# X %8.4f %8.4f %8.4f %8.4f\n" % (xmag, ymag, xcen, ycen)
            os.system("echo \"circle %f %f 5 # color=red\" | xpaset WFS regions" % (xcen, ycen))
            os.system("echo \"image;text 256 20 # text={%s rows, %s cols}\" | xpaset WFS regions" % (rows, cols))
    elif mode == 'F5' and rows == '14' and cols == '14':
        daolines[0] = "# X %s %s %s %s" % (xmag, ymag, xc, yc)
        os.system("echo \"circle %f %f 5 # color=yellow\" | xpaset WFS regions" % (float(xc), float(yc)))
    else:
        daolines[0] = "# X %s %s %8.4f %8.4f\n" % (xmag, ymag, xcen, ycen)
        os.system("echo \"circle %f %f 5 # color=red\" | xpaset WFS regions" % (xcen, ycen))

    dao = open(fitsfile.replace('fits', 'dao'), 'w')
    dao.write("# %s\n" % fitsfiles)
    dao.writelines(daolines)
    dao.flush()
    dao.close()

def zernikes(fitsfile, mode, ref, rotangle):
    if mode == 'F9':
        zern = os.popen("/mmt/shwfs/getZernikesAndPhases %s %s 0 %s" % (ref, fitsfile.replace('fits', 'dao'), rotangle))
    else:
        zern = os.popen("/mmt/shwfs/getZernikesAndPhases_f5 %s %s 0 %s" % (ref, fitsfile.replace('fits', 'dao'), rotangle))

    print zern.read()

########################################################################3

scale = {}
scale['F5'] = 0.135
scale['F9'] = 0.12
sky = {}
sky['F5'] = 0.297
sky['F9'] = 0.167

ref = {}
ref['F5'] = "/mmt/shwfs/f5sysfile.cntr"
ref['F9'] = "/mmt/shwfs/f9newsys.cntr"

fitsfiles = sys.argv[1]
mode = sys.argv[2]
fitsfile = average(fitsfiles)
if fitsfile.find('/') is -1:
    fitsfile = "%s/%s" % (os.getcwd(), fitsfile)
hdu = rfits(fitsfile)
im = hdu.data
hdr = hdu.header
try:
    rot = hdr['ROT']
except KeyError:
    rot = 0.0

im = im + 32768

xdim = hdr['NAXIS1']
ydim = hdr['NAXIS2']
os.system("xpaset -p WFS cd `pwd`")
os.system("xpaset -p WFS file %s" % fitsfile)

xcen, ycen, spots = daofind(im)

if spots:
    avfile = fitsfile.replace('fits', 'dao')
    print avfile, rot
    shcenfind(fitsfile,mode,xcen,ycen)
    
