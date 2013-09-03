#!/usr/bin/env python

# This script does the centroid calculations.
# It is called from shwfs_unified.tcl when the Centroid
# button is pushed, or when a centroid MSG message is received.
#
# It is invoked (for example) as "daofind.py file,file,file F9 0
# It reads the FITS file (averaging them if there is more than one)
# then uses iraf to do background subtraction,
# and scipy.ndimage to do the centroiding.
# For the input file "manual_wfs_0001.fits,
# it writes centroid information to manual_wfs_0001.dao

#import DNS
import re
import os
import socket
from math import *
import sys
import re
import getopt
import numpy
import scipy.ndimage as nd
import pyfits
import imagestats
from scipy import optimize
import pylab
from numpy import *
from pyraf import iraf

def srv_lookup(service):
    DNS.DiscoverNameServers()
    srv_req = DNS.Request(qtype='srv')
    srv_result = srv_req.req('_%s._tcp.mmto.arizona.edu' % service)
    for res in srv_result.answers:
        if res['typename'] == 'SRV':
            port = res['data'][2]
            host = res['data'][3]

    return (host, port)

def read_centroids(file):
    fp = open(file, 'r')
    lines = fp.readlines()
    fp.close()
    p = re.compile('# X')
    for line in lines:
        if p.match(line):
            (dum1, dum2, xmag, ymag, xc, yc) = line.split(' ')
    if xc:
        xc = float(xc)
        yc = float(yc)
        xmag = float(xmag)
        ymag = float(ymag)
    #data = pylab.load(file)
    #data = mlab.load(file)
    data = numpy.loadtxt(file)
    return (data, xmag, ymag, xc, yc)

def write_centroids(file, data, xmag, ymag, xc, yc, title=None):
    fp = open(file, 'w')
    fp.write("# %s\n" % (title or file))
    fp.write("# X %f %f %f %f\n" % (xmag, ymag, xc, yc))
    for i in data:
        fp.write("%f %f\n" % (i[0], i[1]))
    fp.flush()
    fp.close()

def write_spots(file, data):
    fp = open(file, 'w')
    for s in data:
        fp.write("%f %f\n" % (s[0], s[1]))
    fp.flush()
    fp.close()

# the original
def opt_function(offset, refdat, dat):
    xoff = offset[0]
    yoff = offset[1]

    xdat = dat[:,0]
    ydat = dat[:,1]

    # never used and not needed.
    #nref = refdat.shape[0]
    #ndat = dat.shape[0]

    t = 0

    # notice that x, y, r are arrays in the following.
    for spot in refdat:
        x = xdat - (spot[0] + xoff)
        y = ydat - (spot[1] + yoff)
        r = x**2 + y**2
	rmin = min(r)
	t += rmin

    return t

# with toms hack
def opt_function_tom(offset, refdat, dat):
    xoff = offset[0]
    yoff = offset[1]

    xdat = dat[:,0]
    ydat = dat[:,1]

    t = 0

    # notice that x, y, r are arrays in the following.
    for spot in refdat:
        x = xdat - (spot[0] + xoff)
        y = ydat - (spot[1] + yoff)
        r = x**2 + y**2
	rmin = min(r)
	# tjt - reject spots with ridiculous matches.
	if rmin < 289 :
	    t += rmin

    return t

def dimm_seeing(fwhm, ref_fwhm, scale):

    #print "ref_fwhm = %s" % (ref_fwhm)
    #print "scale = %s" % (scale)

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

def ds9spots(file, xcol, ycol, color, size):
    data = file.split('\.')
    reg = data[0] + ".reg"
    xpa = open(reg, 'w')
    xpa.write("# Region file format: DS9 version 3.0\n")
    xpa.write("# Filename: %s\n" % file)
    xpa.write("global color=%s font=\"helvetica 10 normal\" select=1 edit=1 move=1 delete=1 include=1 fixed=0 source\n" % color)
    
    p = re.compile('#')
    spots = open(file, 'r')
    for line in spots:
        if p.match(line):
            data = line
        else:
            data = line.split()
            x = data[xcol]
            y = data[ycol]
            xpa.write("image;circle(%f,%f,%d) # color = %s\n" % (float(x), float(y), size, color))

    xpa.close()
    os.system("cat %s | xpaset WFS regions" % reg)

def rfits(file):
    f = pyfits.open(file)
    hdu = f[0]
    (im, hdr) = (hdu.data, hdu.header)
    f.close()
    return hdu

# argument 1 - file - the name of the fits file
# argument 2 - scale - pixel scale (depends on mode)
# argument 3 - ref - from the reference file as follows: (it is reffwhm_pix in the following)
#    ffile = open("/mmt/shwfs/%s_reference.fwhm" % mode, 'r')
#    [reffwhm, reffwhm_pix] = ffile.read().split()
#    reffwhm = float(reffwhm)
#    reffwhm_pix = float(reffwhm_pix)
#    ffile.close

def get_seeing(file, scale, ref):

#    log = file.replace('fits','psf')		# never used

# Gets called with full path to the fits file
#    print "daofind get_seeing: ", file

    iraf.noao()
    iraf.noao.obsutil()
    iraf.set(stdgraph="uepsf")

    # name of file with coordinates of star images.
    coords = file.replace('fits','dao')

    data = iraf.psfmeasure(file, coords='markall', wcs='logical', display='no', frame=1, level=0.5, size='FWHM', radius=10.0, sbuffer=1.0, swidth=3.0, iterations=1, logfile=log, imagecur=coords, Stdout=1)

    # print "daofind psfmeasure data: ", data
    # last = data.pop()
    # data.append(last)
    # print "daofind psfmeasure last line of data: ", last
    # psfmeasure returns lots of information (data for each spot), but we just
    # want the last line (the average fwhm), which looks like:
    # Average full width at half maximum (FWHM) of 6.0163

    fwhm = data.pop().split().pop()
    print "daofind psfmeasure fwhm: ", fwhm

    fwhm_pix = float(fwhm)
    fwhm = fwhm_pix*scale
    seeing = dimm_seeing(fwhm_pix, ref, scale)
    print "Seeing: ", seeing

    seeingfile = file.replace('fits','seeing')
    fp = open(seeingfile, 'w')
    fp.write("%f %f\n" % (fwhm_pix, seeing))
    fp.close()

    os.system("echo \"image;text 85 500 # text={Spot FWHM = %5.2f pixels}\" | xpaset WFS regions" % fwhm_pix)
    os.system("echo \'image;text 460 500 # text={Seeing = %4.2f\"}\' | xpaset WFS regions" % seeing)
    os.system("echo \"set wfs_seeing %4.2f\" | nc hacksaw 7666" % seeing)

def get_center(im, xrefcen, yrefcen):
    (ycen, xcen) = nd.center_of_mass(im)
    #(ycen, xcen) = pos[0]
    xcen = xcen+1
    ycen = ycen+1
    
#    print "Pupil Center: X = %7.3f, Y = %7.3f" % (xcen, ycen)
#    os.system("echo \"circle %f %f 5 # color=yellow\" | xpaset WFS regions" % (xcen, ycen))

    xoff = xcen - xrefcen
    yoff = ycen - yrefcen

#    print "Pupil Offset: X = %7.3f, Y = %7.3f" % (xoff, yoff)
#    print "                  %6.2f\",     %6.2f\"" % (xoff*scale[mode]/sky[mode], yoff*scale[mode]/sky[mode])

    return (xcen, ycen)

def daofind(im):
    cfile = open("/mmt/shwfs/%s_reference.center" % mode, 'r')
    [xrefcen, yrefcen] = cfile.read().split()
    xrefcen = float(xrefcen)
    yrefcen = float(yrefcen)
    cfile.close

    im = im*1.0
    allstats = imagestats.ImageStats(im)
    stats = imagestats.ImageStats(im, nclip=5)
    mean = stats.mean
    sig = stats.stddev
    max = stats.max

    print "Mean = ", mean
    
    if mode == 'F9':
        smooth = nd.gaussian_filter(im, 5.0)
        maxstars = 140
        nsig = 5.0
    elif mode == 'F5':
        smooth = nd.gaussian_filter(im, 3.0)
        maxstars = 140
        nsig = 5.0
    else:
        smooth = nd.gaussian_filter(im, 1.1)
        nsig = 8.0
        maxstars = 155
        
    nstars = 0
    maxstars = maxstars - spottol

    while nstars < maxstars:
        spot_clip = smooth >= (mean + nsig*sig)
        labels, num = nd.label(spot_clip)
        nstars = num
        nsig = nsig - 0.02
        if nsig <= 1.5:
            break
#        print num, " spots found."

    if nstars < maxstars:
        print "Pupil too far off image or seeing too poor."
        os.system("echo \"image;text 256 500 # text={Seeing too poor or pupil too far off image.}\" | xpaset WFS regions")
        return (False, False, False)
    
    if mode == 'F9':
        clip = smooth >= (mean + (nsig+2.0)*sig)
    elif mode == 'F5':
        clip = smooth >= (mean + (nsig-2.0)*sig)
    else:
        clip = smooth >= (mean + (nsig-2.0)*sig)

    pos = nd.center_of_mass(im, labels, range(num))
    counts = numpy.array( nd.sum(im, labels, range(num)) )
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
        if mode == 'MMIRS':
            if x < 450 and y < 450 and x > 50 and y > 50:
                spots.append( (x, y, c) )
                dao.write("%8.3f  %8.3f\n" % (x, y))
        else:
            if x < 500 and y < 500 and x > 5 and y > 5:
                spots.append( (x, y, c) )
                dao.write("%8.3f  %8.3f\n" % (x, y))
        
    dao.close()

    if mode == 'MMIRS':
        cen_clip = nd.gaussian_filter(im, 3.0) >= 50
    else:
        if mean < 750.0:
            cen_clip = nd.gaussian_filter(im, 20.0) >= mean
        else:
            cen_clip = nd.gaussian_filter(im, 20.0) >= 750
    
    (xcen, ycen) = get_center(cen_clip, xrefcen, yrefcen)

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

    # in the following column1 = column2 * scale
    # and we never use the value in column1
    ffile = open("/mmt/shwfs/%s_reference.fwhm" % mode, 'r')
    [reffwhm, reffwhm_pix] = ffile.read().split()
    reffwhm = float(reffwhm)	# never used
    reffwhm_pix = float(reffwhm_pix)
    ffile.close

    if mode == 'F9':
        pipe = os.popen("export WFSROOT=/mmt/shwfs; /mmt/shwfs/shcenfind %s" % fitsfile.replace('fits', 'dao'))
    if mode == 'F5':
        pipe = os.popen("export WFSROOT=/mmt/shwfs; /mmt/shwfs/shcenfind_f5 %s" % fitsfile.replace('fits', 'dao'))
    if mode == 'MMIRS':
        pipe = os.popen("export WFSROOT=/mmt/shwfs; /mmt/shwfs/shcenfind_mmirs %s" % fitsfile.replace('fits', 'dao'))

    daofile = fitsfile.replace('fits', 'dao')
    shift_ref = fitsfile.replace('fits', 'ref')	# never used (but good idea - tjt)

    rows, cols = pipe.read().split()
    print "Found %s rows and %s cols." % (rows, cols)

    if float(rows) < 10 or float(cols) < 10:
        os.system("echo \"image;text 256 500 # text={WFS pattern not found.}\" | xpaset WFS regions")
        return False

    ds9spots(daofile, 0, 1, 'red', 1)
    get_seeing(fitsfile, scale[mode], reffwhm_pix)

    (star, xmag, ymag, xc, yc) = read_centroids(daofile)
    (refdat, xrmag, yrmag, xrc, yrc) = read_centroids(ref[mode])

    print "fmin, dao header = ", xmag, ymag, xc, yc
    print "fmin, ref header = ", xrmag, yrmag, xrc, yrc

    # tjt says, lets calculate the overall "mag" just like
    # we will do in getZernikesAndPhases, and apply it here,
    # before we optimize the center offset

    mag = (xrmag+yrmag)/(xmag+ymag)
    print "fmin, mag = ", mag

    # these files get written into datadir
    #write_spots ( "tom_ref.dat", refdat )
    #write_spots ( "tom_star.dat", star )

    # Tom's first fix, scale spots before attempting optimization.
    # scale the spots, keeping the center unmoved.
    if toms_mode :
	center = array([xc,yc])
	star -= center
	star *= mag
	star += center

    # dump the star with rescaled spots
    write_spots ( "tom_star2.dat", star )

    # calculate a starting value for the optimization.
    guess = array([xc-xrc,yc-yrc])

    rval = opt_function ( guess, refdat, star )
    print "fmin_powell initial offset = ", guess[0], guess[1], rval

    # dump the star with rescaled spots, also moved to ref center
    write_spots ( "tom_star3.dat", star - guess )

    # Tom's second fix, use an optimization function that omits spots far
    # aways from possible correlated spots.
    if toms_mode :
	os.system("echo \"image;circle %f %f 5 # color=yellow\" | xpaset WFS regions" % (xc, yc))
	fit = optimize.fmin_powell(opt_function_tom, guess, args=(refdat,star), xtol=0.0001, disp=False)
	rval = opt_function_tom ( fit, refdat, star )
	os.system("echo \"image;circle %f %f 5 # color=blue\" | xpaset WFS regions" % (xrc+fit[0], yrc+fit[1]))
    else :
	os.system("echo \"image;circle %f %f 5 # color=yellow\" | xpaset WFS regions" % (xc, yc))
	fit = optimize.fmin_powell(opt_function, guess, args=(refdat,star), xtol=0.0001, disp=False)
	rval = opt_function ( fit, refdat, star )

    # dump the star, moved to optimized center
    #write_spots ( "tom_star4.dat", star - fit )

    print "fmin_powell final offset = ", fit[0], " ", fit[1], rval

    # Tom's third and most important fix, actually apply the optimized center.
    #  If we offset both the spots and the center value in the header,
    #  then when we get into getZernikesAndPhases and subtract out the center,
    #  the offset we just so carefully determined simply cancels and disappears.
    if toms_mode :
	#xrc -= fit[0] # close
	#yrc -= fit[1]
	xrc = xc - fit[0] # correct
	yrc = yc - fit[1]
    else :
	refdat[:,0] += fit[0]
	refdat[:,1] += fit[1]
	xrc += fit[0]
	yrc += fit[1]

    print "fmin_powell done, xyrc = ", xrc, " ", yrc

    write_centroids('ref.dat', refdat, xrmag, yrmag, xrc, yrc, title="reference for %s" % fitsfile)

#    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
#    sock.connect(srv_lookup("wfs"))
#    sock.send("1 reference ref.dat\n")
#    sock.close
#    ds9spots('ref.dat', 0, 1, 'green', 10)

    return True

# Never called.
def zernikes(fitsfile, mode, ref, rotangle):
    if mode == 'F9':
        zern = os.popen("/mmt/shwfs/getZernikesAndPhases %s %s 0 %s" % (ref, fitsfile.replace('fits', 'dao'), rotangle))
    if mode == 'F5':
        zern = os.popen("/mmt/shwfs/getZernikesAndPhases_f5 %s %s 0 %s" % (ref, fitsfile.replace('fits', 'dao'), rotangle))
    if mode == 'MMIRS':
        zern = os.popen("/mmt/shwfs/getZernikesAndPhases_mmirs %s %s 0 %s" % (ref, fitsfile.replace('fits', 'dao'), rotangle))
    print zern.read()

def draw_dirs(rot, off, daofile):
    l = 35.0
    cntr = open(daofile, 'r')
    pound, char, xmag, ymag, x, y = cntr.readlines()[1].split()
    x = float(x)
    y = float(y)
    el = rot + off + 90
    az = el + 270
    ang = pi*(rot + off)/180.0

    az_y = l/( (sin(ang)**2/cos(ang)) + cos(ang) )
    az_x = -1.0*az_y*sin(ang)/cos(ang)
    el_y = l/( (cos(ang)**2/sin(ang)) + sin(ang) )
    el_x = el_y*cos(ang)/sin(ang)

    laz_y = (l-10.0)/( (sin(ang)**2/cos(ang)) + cos(ang) )
    laz_x = -1.0*laz_y*sin(ang)/cos(ang)
    lel_y = (l-10.0)/( (cos(ang)**2/sin(ang)) + sin(ang) )
    lel_x = lel_y*cos(ang)/sin(ang)

    el_x += x
    el_y += y
    az_x += x
    az_y += y

    lel_x += x
    lel_y += y
    laz_x += x
    laz_y += y

    os.system("echo \'image;text %f %f  # text={+El}\' | xpaset WFS regions" % (el_x, el_y))
    os.system("echo \'image;text %f %f  # text={+Az}\' | xpaset WFS regions" % (az_x, az_y))
    os.system("echo \'image;vector %f %f 25 %f' | xpaset WFS regions" % (x, y, az))
    os.system("echo \'image;vector %f %f 25 %f' | xpaset WFS regions" % (x, y, el))
       
########################################################################

scale = {}
scale['F5'] = 0.135
scale['F9'] = 0.12
scale['MMIRS'] = 0.208

sky = {}
sky['F5'] = 0.297
sky['F9'] = 0.167
sky['MMIRS'] = 0.297

rotoff = {}
rotoff['F5'] = 135.0
rotoff['F9'] = -225.0
rotoff['MMIRS'] = 180.0

fitsfiles = sys.argv[1]
mode = sys.argv[2]
spottol = int(sys.argv[3])
toms_mode = int(sys.argv[4])

fitsfile = average(fitsfiles)
if fitsfile.find('/') is -1:
    fitsfile = "%s/%s" % (os.getcwd(), fitsfile)

# This will create a file datadir/manual_wfs_0000.tom
# if we are running with toms mods.
tomsfile = fitsfile.replace('fits', 'tom')
if toms_mode :
    print "New daofind changes by tom are active"
    os.system("touch %s" % tomsfile)
else:
    os.system("rm -f %s" % tomsfile)

# Subtract background
# Note that with iraf 2.16, the crutil package moved.
os.system("rm -f back.fits")
iraf.images()
iraf.images.imfit()
iraf.images.imutil()
#iraf.crutil()
iraf.noao()
iraf.noao.imred()
iraf.noao.imred.crutil()
iraf.set(uparm="./uparm")

if mode == 'MMIRS':
    iraf.imsurfit(fitsfile, 'back.fits', xorder=3, yorder=3, upper=2, lower=2, ngrow=35, rows='[20:510]', columns='[20:510]')
    iraf.imarith(fitsfile, '-', 'back.fits', fitsfile)
    iraf.cosmicrays(fitsfile,fitsfile,interactive='no',threshold=20,fluxratio=3,window=7)
else:
    iraf.imsurfit(fitsfile, 'back.fits', xorder=2, yorder=2, upper=2, lower=2, ngrow=15)
    iraf.imarith(fitsfile, '-', 'back.fits', fitsfile)

hdu = rfits(fitsfile)
hdu.verify('fix')
image = hdu.data
hdr = hdu.header
try:
    rot = hdr['ROT']
except KeyError:
    rot = 0.0

hdr_debug = 1
if hdr_debug:
	print "image header ROT = ", hdr['ROT']
	print "image header EL = ", hdr['EL']
	print "image header AZ = ", hdr['AZ']

os.system("xpaset -p WFS cd `pwd`")
os.system("xpaset -p WFS file %s" % fitsfile)

ref = {}
ref['F5'] = "/mmt/shwfs/f5sysfile.cntr"
ref['F9'] = "/mmt/shwfs/f9newsys.cntr"
try: 
    mmirscam = hdr['WFSNAME']
except KeyError:
    mmirscam = "mmirs2"
ref['MMIRS'] = "/mmt/shwfs/%s_sysfile.cntr" % mmirscam

xcen, ycen, spots = daofind(image)

# The shwfs_unified script looks for a line with ".dao" in it
# as the last line output from this script.
if spots:
    avfile = fitsfile.replace('fits', 'dao')
    if shcenfind(fitsfile,mode,xcen,ycen):
        print avfile, rot

os.system( "/mmt/shwfs/see_forever %s %s" % (fitsfiles, mode)  )

sys.exit()

# THE END
