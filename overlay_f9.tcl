#! /usr/bin/wish

#scw: overlay.tcl: 3-28-02
# useage: overlay.tcl file.fits. The script gets the gif image from convert,
# and outputs the .cntr file.

# 4-22-02: adapted to centroid with IRAF imcentroid routine, but results
# were highly unstable.  Renamed to overlay_imcentroid.tcl and abandonded.
# This routine will now uses IRAF STARFIND for determining the centroids.

# 5-31-02: overlay mask geometry is saved (in maskfile) and reproduced for
# convenience of reducing sequences of frames -- works great.

# 5-14-03: convert for use with f/9 stuff

# set the root directory if it's not already set
set test ""
catch {set test $env(WFSROOT)}
if { $test == "" } {
    set env(WFSROOT) /home/tim/MMT/shwfs
}

# don't put border on canvas, because it offsets the coords!
set ovc [canvas .ovr_cn -width 512 -height 512 ]

set cenfr [frame .f]
set sclp [button $cenfr.sp -text Mag+ -command {mag_pl}]
set sclm [button $cenfr.sm -text Mag- -command {mag_mn}]

set abort [button $cenfr.abort -text Discard -command abort]

set fitsfile [lindex $argv 0]
set rfile [lindex [split $fitsfile .] 0]
set gfile ${rfile}.gif
set ofile ${rfile}.targets ; # centroid targets
set cfile ${rfile}.cntr ; # reduced centroids
set sffile ${rfile}.daofind ; # raw daophot output
set tiltfile ${rfile}_tot_tilts

if {[regexp {\/} $fitsfile]} {
    set gobut [button $cenfr.ex -text Accept -command {docen; eval exec "$env(WFSROOT)/showcenter.pl $fitsfile"; exit}]
} else {
    set gobut [button $cenfr.ex -text Accept -command {docen; eval exec "$env(WFSROOT)/showcenter.pl `pwd`/$fitsfile"; exit}]
}

# take the desired reference as the 2nd argument and then make a mask
# file suitable for tkcanvas consumption
set reference [lindex $argv 1]
eval exec "$env(WFSROOT)/mkpupmask.pl $reference > f9pupmask.org"

# set up the reference center and magnification for the reference file
# which contains the reference mask positions. The file "masksave" has the
# coord setup for the last used mask positions.  

# first read the reference file to get the center and mag
set fid [open $reference r]
set tmp [read $fid]
close $fid
set line [lindex [split $tmp \n] 0]

if {[lindex $line 1] == "X"} {
    set RMAG [expr ([lindex $line 2] + [lindex $line 3])/2.0]
    set XCR [expr [lindex $line 4] - 4]
    set YCR [expr 512 - ([lindex $line 5] + 3)]
} else {
    set XCR 251 
    set YCR [expr 512 - 253]
    set RMAG 14.1
}

set SCLR 1.0 ; # canvas scale

if {[file exists "masksave"]} {
    set fid [open "masksave" r]; # open the last saved mask geometry
    set mgeo [read $fid]
    close $fid

    set SCL [lindex $mgeo 2] ; # set last-used magnification
    set XC [lindex $mgeo 4] ; # set last-used x-center
    set YC [expr 512 -[ lindex $mgeo 5]] ; # y-center converted to canvas coord
} else {
    set SCL 1.0
    set XC 256
    set YC 256
}

eval exec "convert -normalize $fitsfile $gfile"

image create photo ttt -file $gfile

$ovc create image 256 256 -tag spotImg ; # assumes 512 x 512 image

$ovc itemconfigure spotImg -image ttt

pack $ovc 
grid configure $sclp -column 0 -row 0
grid configure $sclm -column 1 -row 0

grid configure $gobut -column 2 -row 0 -sticky news
grid configure $abort -column 3 -row 0 -sticky news

#pack $dobut $sclp $sclm $gobut
pack $cenfr

set dx 8; # box radius for centroid targets
set boxsz [expr $dx * 2]

# canvas delete mask for f9 pupil (not for general use)
set dlist "2 3 4 13 14 15 16 27 28 40 41 73 74 85 86 87 99 100 170 169 168 158 159 160 157 145 146 144 131 132"
 
 
# read in pupil mask and draw to canvas.
# first step is to draw the mask with the reference geometry which is just
# the coords saved in f9pupmask.org, then use canvas math to convert it to
# the last-saved geometry

set maskID [open "f9pupmask.org" r]
set msktmp [read $maskID]
close $maskID
  
set mskpos [split $msktmp \n]
  
set mskx "" ; set msky ""
foreach pos $mskpos {
  
    if {($pos) != ""} {
	set ytmp [lindex $pos 1]
	set yt [expr 512.0 - $ytmp] ; #convert from image to canvas coords
	lappend mskx [lindex $pos 0]
	lappend msky $yt
    }
}
  
# canvas ID: 1=cens, 2-N are the boxes drawn
set cntr 1
foreach mx $mskx my $msky {
    incr cntr
    $ovc create rectangle [expr $mx - $dx] [expr $my - $dx] \
	[expr $mx + $dx] [expr $my + $dx] -outline red \
	-tags cens 
}
set Lspot $cntr; # spot ID 2 through Lspot

#draw mask center; tag to move with mask (cens)
$ovc create rectangle $XCR $YCR $XCR $YCR -outline white \
    -tags {cens center}

#draw in pupil and spider geometry
#$ovc create line 254 0 254 511 -fill blue
#$ovc create line 0 242 511 242 -fill blue
#$ovc create oval 44 30 464 454 -outline blue

#trim spots from full lenslet geometry (early use)
#foreach it $dlist {$ovc delete $it} 


# the mask with reference position is now drawn.  Apply the masksave offsets
# and magnification (assume ref mag = 1)

set dxc [expr $XC - $XCR]; # offset to last-saved XC
set dyc [expr $YC - $YCR]
$ovc move cens $dxc $dyc
$ovc scale cens $XC $YC $SCL $SCL

#  ---------------------------------------------------------
#  this section is for collecting the lenslet image coordinates
set ovmsk [open "f9pupmask" w]
close $ovmsk; # erases existing file

bind $ovc <ButtonPress-2> { 
    set x %x ; set y [expr 512 - %y] ; # convert from canvas to image coords
    set out "$x $y"
    set ovmsk [open "f9pupmask" a]
    #set out [format "%5d %5d" $x $y]; this doesn't work -- a bug! 
    puts  "%x %y" 
    puts $ovmsk $out
    close $ovmsk
    $ovc create rectangle [expr %x] [expr %y] \
	[expr %x] [expr %y] -outline blue
  
}
# ---------------------------------------------------------

# move centroid target boxes around on canvas

bind $ovc <ButtonPress-1> {
     set xs %x ; set ys %y
     set xf %x ; set yf %y
    $ovc move cens [expr $xf-$xs] [expr $yf - $ys]
}
 
bind $ovc <ButtonRelease-1> {
    set slide 0
    set xf %x ; set yf %y
    $ovc move cens [expr $xf-$xs] [expr $yf - $ys]
}

bind $ovc <B1-Motion> {
    set xf %x; set yf %y
    $ovc move cens [expr $xf-$xs] [expr $yf - $ys]
    set xs %x ; set ys %y
}

# draw centroid centers of boxes (centroid target coords), and then output
# the targets to a file (in image pixel coords--not tk canvas coords).

#bind $ovc <ButtonPress-3> {
#	set xim "" ; set yim ""

#	set fid [open $ofile w]
#	for {set i 2} {$i <= $Lspot} {incr i} {
#		set bc [$ovc coords $i]
#		set bcx [expr [lindex $bc 0] + $dx] 
#		set bcy [expr [lindex $bc 1] + $dx]
#		set imy [expr 512 - $bcy] ; # convert to image coords
#		$ovc create rectangle $bcx $bcy $bcx $bcy -outline green

#		puts $fid  "$bcx $imy" 
#	}

#	close $fid
#}
#----------------------------------------------------------------------

proc abort {} {
    global cfile sffile

    eval exec rm -f $cfile $sffile

    exit
}

# This procedure is called when the user has aligned the pupil mask to the
# spot diagram.  The coords are saved and an ihwfs-type header (e.g. # X mx
# my cx cy) so that associateSpots() will work with the files. Since
# STARFIND is used for centroiding, the target boxes are ignored since
# starfind finds spots independently.  However, by aligning the target boxes,
# the center and magnification of the spot pattern are obtained.

proc docen { } {

    global ovc Lspot ofile dx fitsfile cfile sffile tiltfile refx refy \
	SCL RMAG reference env thresh hwhm 

    # ofile is the centroid target file
    set xim "" ; set yim ""

    #get center of shifted pupil mask
    set cc [$ovc coords center]
    set xc [lindex $cc 0]
    set yci [expr 512 - [lindex $cc 1]] ; # converts canvas to image coords

    set mag [expr $RMAG*$SCL]

    set ihwfs "# X $mag $mag $xc $yci" ; # ihwfs scale-center header
    set save "# X $SCL $SCL $xc $yci" ; # masksave scale-center header

    # save mask geometry (in image -- not canvas-- coords)
    set fid [open "masksave" w]
    puts $fid $save
    close $fid

    # read the daophot output file.  Strip out the x and y image coords.
    # Convert image coords to primary mirror coord system. Add ihwfs
    # mag-center header to beginning of new file ($sffile.cntr)

    # read daophot output file
    set fid [open $sffile r]
    set tmp [read $fid]
    close $fid
    set data [split $tmp \n]

    # extract xy centroid coords from starfind file
    set xpi "" ; set ypi ""; # clear pupil image spot coords

    for {set i 0} { $i < [expr [llength $data] -1]} {incr i} {
	set line [lindex $data $i]
	if {[regexp {#} $line] || 
	    $line == ""} {continue}
	set xs [lindex $line 0] ; set ys [lindex $line 1]

	lappend xpi $xs ; lappend ypi $ys ; # image spot centroid coords
    }

    # convert image coords to primary mirror coords.  There are three steps
    # to this: 1) remove CCD inversions at rot=0, 2) find angular offset for
    # rot=0, and 3) correct for arbitrary rot angle.

    # store centroids file
    set cfid [open $cfile w]
    puts $cfid $ihwfs ; # put in ihwfs-style mag-center header
    foreach x $xpi y $ypi {
	puts $cfid [format "%10.3f %10.3f" $x $y]
    }

    close $cfid

}
#----------------------------------------------------------------------

proc mag_pl { } {

    global ovc SCL XC YC

    set SCL [expr $SCL * 1.01]
	
    #get center of shifted pupil mask
    set cc [$ovc coords center]
    set XC [lindex $cc 0]
    #set YC [expr 512 - [lindex $cc 1]] ; # converts canvas to image coords
    set YC [lindex $cc 1] 
    $ovc scale cens $XC $YC 1.01 1.01

}
		
	
proc mag_mn { } {

    global ovc SCL XC YC

    set SCL [expr $SCL * 0.99]
    #get center of shifted pupil mask
    set cc [$ovc coords center]
    set XC [lindex $cc 0]
    #set YC [expr 512 - [lindex $cc 1]] ; # converts canvas to image coords
    set YC [lindex $cc 1]
    $ovc scale cens $XC $YC .99 .99

}

# run the centroids first off...
docen
