#!/usr/bin/wish

# tjt 7-18-2012
# look into giving the zforces file a unique name so that
# we can look at what forces were applied (or were attempted
# to be applied) throughout the night.

# tjt 2-8-2011
# A chat with John McAfee about using this for manual WFS
#
# 1 - take the exposure
# 2 - hit Apply/Refresh to get new list of files
# 3 - select top file (or file of choice)
# 4 - hit Centroid
# 5 - go to Wavefront Zernikes window and use one
#	of the 4 buttons on the bottom to do what you want.
# --- John has no idea what Average, Aberr, or Set System do.
# --- John does use the Clear Forces button, typically before
# ---   he begins a WFS sequence.

#   scw; shwfs.tcl; update: 6-11-02
# Interferometric Hartmann wavefront sensor data reduction tcl script.
# This routine handles everything from receiving the image files to
# visualizing the wavefront aberrations to producing spot diagrams and
# calculating optimization force patterns.

# The wfs.avctr frame handles centroiding and averaging the interferograms.
# A radiobutton handles filtering the file data and enabling corresponding
# procedures.

# note 8-17-00: zernike labels and angles worked on (they're still wrong) as
# well as moving the whole analysis to monomial zernikes. 

# note 8-18-00: changed the results graphing to a canvas for better 
# organization.  Also note that the xpm images are getting rotated by 90-deg
# somehow. Fixed the action button lockouts and colors. Removed the actuator
# forces bargraph since it was useless.

# 8-19-00 added a scrolling list to report actuator forces in place of the
# bargraph.  Changed tixScrolledTList to tixScrolledListBox for the file
# manager since it has one column which works better for the purpose.

# 9-12-00 added a manual alignment tool to "View Join" for tweeking that last
# bit of alignment between interferograms.  New offsets and mags flushed to
# stellar file with push button.

# 1-10-02: moved files from c_devel/ to current directory--repointed CENHOME
# and AVHOME to current directory.

# 5-02: renamed ihwfs.tcl to shwfs.tcl because I started using this routine
# to manually reduce shack hartmann data. Changed the centroid procedure to
# use overlay.tcl rather than list_centroids.

# 6-5-02: renamed shwfs.tcl to shwfs_inter.tcl to freeze that version which
# allows fully manual control of the whole process.  This version of
# shwfs.tcl starts there and after centroiding, processes the entire
# mess right to the display zernike window (i.e. automatically calls,
# average(), zernike(), and the display stuff.  

# 6-6-02: Removed the "View Centroids" option.  If something goes wrong to
# the point where this routine is needed, I'll have to intervene. Added a
# check to see if file has already been centroided--if so, don't do it
# again.

# 6-11-02: Added buttons for correcting secondary position, primary
# mirror figure, and associated housekeeping.  Corrected some nagging
# bugs/omissions.

# 9-02-02: Started changing centroid flow. Moved the call to starfind from
# overlay.tcl into this script.  This will allow a call to the new
# shcenfind.c independent of any input from overlay.tcl.  My basic thought
# is to have this script call starfind, parse out the unwanted columns, send
# this output to shcenfind.c which automatically fills in the ihwfs-style
# header.  If shcenfind fails, then send the file to overlay.tcl for
# interactive processing...  

# 9-03-02: shcenfind is implemented and working (with no error checking).
# shcenfind uses magnification of pixels/row,column, but overlay uses
# magnification of overlay (~1). These header types are incompatible:
# f9system.cntr uses overlay mag, and f9newsys.cntr uses shcenfind mag.

# 9-13-02: replaced interactive zernike file viewer/calculator.  So old
# results can be viewed without having to re-do the entire calculation (uses
# showsernsInt{} as the entrance point from the Load File button).

# 4-16-03: forked a separate f/5 version of this script to call the f/5 
# specific programs and to deal with the different behavior of the f/5 WFS 
# system.

if {!([lindex $argv 0] == "F9" || [lindex $argv 0] == "F5" || [lindex $argv 0] == "MMIRS")} {
    puts "Specify mode."
    exit
} else {
    set fmode [lindex $argv 0]
    puts "In $fmode mode."
}

if {[lindex $argv 1] == ""} {
    puts "Specify Instrument."
    exit
} else {
    set inst [lindex $argv 1]
}

package require Tix
package require BLT
package require dns

set first 1
set last_files {}

wm geometry . +902+491

# A checkbutton used to manipulate this,
# setting it to 1 enables changes tjt made in 3/17/2011
# We have always found these beneficial, so we no longer
# need the checkbutton to offer the "retro"
set toms_mode 1

# set the debug option
set debug ""
catch {set debug $env(WFSDEBUG)}
if { $debug != "" } {
    puts "Debug option set from environment to: $debug"
    puts " secondary = $fmode"
    puts " instrument = $inst"
}

# set the root directory if it's not already set
set test ""
catch {set test $env(WFSROOT)}
if { $test == "" } {
    set env(WFSROOT) /mmt/shwfs
}

# look for DS9 and fire it up if it's not there
set x ""
catch {set x [exec xpaget WFS]}
if {$x == ""} {
    if {$fmode == "F9"} {
	exec ds9 -title WFS -geometry 650x770 &
    } else {
	exec ds9 -title WFS -geometry 654x770-15+179 -source $env(WFSROOT)/observemenu.tcl &
    }
}

# look for John Roll's wavedisplay gui locally and run it
if {$fmode == "F5" && $debug != "postmortem"} {
    set wavedisp "$env(WFSROOT)/wavedisplay"
    if {[file exists $wavedisp]} {
	exec $wavedisp &
    }
}

set bin_dir "$env(WFSROOT)";           # set executable directory
set data_dir "$env(WFSROOT)/datadir";  # set data dir   

#cd "./"
cd "$data_dir"
exec rm -f daopars
exec rm -f F9
exec rm -f F5
exec rm -f MMIRS

set maxM2tilt 500; # max M2 vertex tilt allowed by program (safety)

#make shortcut to the average and centroiding frame of .wfs
set AVC ".wfs.avctr"

# reference foci for various instruments
set ref_foc(Blue) 7982
set ref_foc(Red) 7982
set ref_foc(SPOL) -308
#set ref_foc(Pisces) 887

# determined by jmcafee and rfinn 02-2006 to be 887 nm + 170 um for
# the J filter.  ends up pretty close to blue/red.
set ref_foc(Pisces) 6786

set ref_foc(MegaCam) -468
#set ref_foc(Hecto) 2967
set ref_foc(Hecto) -2810
#set ref_foc(Maestro) -2810
set ref_foc(Maestro) -1920
set ref_foc(SWIRC) -2017
set ref_foc(MMIRS) 612

set ref_spher(MegaCam) -80
set ref_spher(Hecto) -150
set ref_spher(Maestro) -150
set ref_spher(SWIRC) -1079
set ref_spher(MMIRS) 0

# reference focus (nm) 
set ref_focus_nm $ref_foc($inst)

# Fixes an annoying complaint
# tjt 3-18-2011
# (but this may not do it in the proper directory,
#  in fact when run by the operator, I think it never does)
exec touch login.cl

switch $fmode {
    F9 {
	exec touch F9
	if { $debug != "postmortem" } {
	    exec $env(WFSROOT)/f9wfs_gui $inst &
	}

	# f/9 specific factors
	set rotangle_def -225;  # angle (deg) to rotate spot patterns for derot
	set rotangle $rotangle_def

	set cc_trans 13.6;   # hexapod translate for M2 CC tilt (um/arcsec)
	set zc_trans 5.86;   # hexapod translate for M2 ZC tilt (um/arcsec)

	set theta_CC 44.4;   # convert nm of coma to arcsec of CC tilt
	set defoc_fact 34.7; # convert nm of defocus to um of hexapod Z 
	                     # motion to focus

	# reference spherical (nm)
	set ref_spher_nm 0 

	# correction gains
	set m1_gain 1.0
	set m2_gain 1.0

	# current and desired centers
	set curr_xcen 256
	set curr_ycen 256
	set xcenter 256
	set ycenter 256
    }

    F5 {
	exec touch F5
	if { $debug != "postmortem" } {
	    exec $env(WFSROOT)/f5wfs_gui $inst &
	}

	set rotangle_def 234;  # angle (deg) to rotate spot patterns for derot
	set rotangle $rotangle_def

	set cc_trans 25;   # hexapod translate for M2 CC tilt (um/arcsec)
	set zc_trans 9.45;  # hexapod translate for M2 ZC tilt (um/arcsec)
	set theta_CC 79;   # convert nm of coma to arcsec of CC tilt
	set defoc_fact 40.8; # convert nm of defocus to um of hexapod Z 

	# reference spherical (nm)
	set ref_spher_nm $ref_spher($inst)

	# correction gains
	set m1_gain 0.5
	set m2_gain 1.0

	# current and desired centers
	set curr_xcen 256
	set curr_ycen 256
	set xcenter 256
	set ycenter 256
    }

    MMIRS {
	exec touch MMIRS
	if { $debug != "postmortem" } {
	    exec $env(WFSROOT)/mmirs_gui &
	}

	# GCAM2 is the reference here. GCAM1 is GCAM2+180. the image acq script
	# will handle this. 
	set rotangle_def 180;  # angle (deg) to rotate spot patterns for derot
	set rotangle $rotangle_def

	set cc_trans 25;   # hexapod translate for M2 CC tilt (um/arcsec)
	set zc_trans 9.45;  # hexapod translate for M2 ZC tilt (um/arcsec)
	set theta_CC 79;   # convert nm of coma to arcsec of CC tilt
	set defoc_fact 40.8; # convert nm of defocus to um of hexapod Z 

	# reference spherical (nm)
	set ref_spher_nm $ref_spher($inst)

	# correction gains
	set m1_gain 0.1
	set m2_gain 0.2

	# current and desired centers
	set curr_xcen 256
	set curr_ycen 256
	set xcenter 256
	set ycenter 256
    }
}

set thetax 0 ; set thetay 0 ; # initialize M2 tilts errors to zero
set spher 0
set focus_nm 0
set focus_um 0

set USEHEX 1 ; # command hexapod: 0 = no (testing), 1 = yes--connect to HEXSERV
set USEREPOINT 1; # repoint telescope after collimation = 1
set BENDMIRROR 1; # bend (1), don't bend (0) primary

#------------------------------------------------------------------------
# set up hexapod server for remotely controlling M2 position

#source "$env(WFSROOT)/msg.tcl"
source /mmt/scripts/msg.tcl

# set up an internal MSG server for remote control of the data analysis
set env(WFSSERV) .:6868

msg_server WFSSERV

msg_allow WFSSERV {
    127.0.0.1        localhost localhost.localdomain
    localhost        127.0.0.1
    192.168.1.150    f5wave
    128.196.100.216  wavefront
    wavefront        wavefront.mmto.arizona.edu
    hacksaw          hacksaw.mmto.arizona.edu
    yggdrasil        yggdrasil.mmto.arizona.edu
    hoseclamp        hoseclamp.mmto.arizona.edu
    pipewrench       pipewrench.mmto.arizona.edu
    chisel           chisel.mmto.arizona.edu
    alewife          alewife.mmto.arizona.edu
    homer            homer.mmto.arizona.edu
}

msg_publish WFSSERV ref_focus_nm ref_focus_nm
msg_publish WFSSERV ref_spher_nm ref_spher_nm
msg_publish WFSSERV focus_um focus_um
msg_publish WFSSERV spher spher
msg_publish WFSSERV m1_gain m1_gain
msg_publish WFSSERV m2_gain m2_gain

# set the WFS reference focus to a specific value
msg_register WFSSERV setref 
proc WFSSERV.setref { s sock msgid cmd focus } {
    setRefFoc $focus
    msg_ack $sock $msgid
}

# set the WFS reference spherical to a specific value
msg_register WFSSERV setspher
proc WFSSERV.setspher { s sock msgid cmd spher } {
    setRefSpher $spher
    msg_ack $sock $msgid
}

# recenter spot pattern on image
msg_register WFSSERV recenter
proc WFSSERV.recenter { s sock msgid cmd } {
    recenter
    msg_ack $sock $msgid
}

# correct coma
msg_register WFSSERV corr_coma
proc WFSSERV.corr_coma { s sock msgid cmd } {
    m2correct
    msg_ack $sock $msgid
}

# correct focus
msg_register WFSSERV corr_focus
proc WFSSERV.corr_focus { s sock msgid cmd } {
    m2focus
    msg_ack $sock $msgid
}

# correct primary
msg_register WFSSERV corr_primary
proc WFSSERV.corr_primary { s sock msgid cmd } {
    m1correct
    msg_ack $sock $msgid
}

# set M1 gain
msg_register WFSSERV m1_gain
proc WFSSERV.m1_gain { s sock msgid cmd g } {
    global m1_gain
    set m1_gain $g
    msg_ack $sock $msgid
}

# set M2 gain
msg_register WFSSERV m2_gain
proc WFSSERV.m2_gain { s sock msgid cmd g } {
    global m2_gain
    set m2_gain $g
    msg_ack $sock $msgid
}

# clear forces
msg_register WFSSERV clearforces
proc WFSSERV.clearforces  { s sock msgid cmd } {
    clear_forces
    msg_ack $sock $msgid
}

# set system file
msg_register WFSSERV reference
proc WFSSERV.reference { s sock msgid cmd file } {
    global systemFile
    set systemFile $file
    msg_ack $sock $msgid
}

# put count of linked spots into our DS9 window
# All this does is to count the lines in the file "link"
# which is written when the getZernikesAndPhases program is run.
#
# getZernikesAndPhases gets called from the zernicke function here,
# which is called from the average routine when either
# the "Average" or "Aberr" button get pushed, we ignore these latter.
# Note that we don't get a link count just when the Centroid button gets
# hit.
proc show_spot_count { sffile } {

    set linkcount [lindex [eval exec wc -l link] 0]

    # count the lines in the ".dao" file and subtract 2 for the header.
    set spotcount [lindex [eval exec wc -l $sffile] 0]
    set spotcount [expr $spotcount - 1]

    set msg "linked $linkcount of $spotcount spots"

    if { $linkcount < 97 } {
	set messg "image;text 280 500 # color=red text={Only $msg!!}"
    } else {
	set messg "image;text 250 500 # text={$msg}"
    }

    # typical tcl brain-damage prevents doing the
    # following obvious thing.  Tcl takes the entire
    # first argument to exec (the entire string that follows)
    # and tells the operating system to find a command
    # by that name.
    #set cmd "echo $messg | xpaset WFS regions"
    #exec "$cmd"

    # But actually, this is nicer ...
    exec xpaset WFS regions << $messg
}

# Here is the centroiding code all in one place tjt 1-24-2011
# The second argument indicates whether this is called from MSG or not.
proc do_centroid { list } {
    global bin_dir env systemFile rotangle rotangle_def fmode
    global toms_mode

    #puts "do_centroid $list"
    
    # suddenly (as of 1-24-2011) we need this!
    if {![file exists "login.cl"]} {eval exec touch login.cl}

    # set up command to do the centroiding
    #set command "$bin_dir/daofind.py $list $fmode 0 2> /dev/null"
    set command "$bin_dir/daofind.py $list $fmode 0 $toms_mode"

    puts "centroid routine calls: $command"

    # call script to do the centroiding
    set fid [open |$command r]
    set tmp [read $fid]
    close $fid

    # parse the response from DAOFIND --
    # response is a lot of chit chat followed by
    # the one line we want, which has the output filename
    # and the rotangle as:
    # manual_wfs_0078.dao -2.05
    set lines [split $tmp \n]

    set sffile "error"

    # parse the header line only
    foreach line $lines {
	# show daofind output to aid debugging
	puts "daofind.py: $line"
	if {[regexp {\.dao} $line]} {
	    set data [split $line " "]
	    set sffile [lindex $data 0]
	    set rotator [lindex $data 1]
	    set rotangle [expr $rotangle_def - $rotator]
	    report "* Done Centroiding.\n"

	}
    }   

    # When daofind.py discovers an error
    # (typically a hopeless image it cannot cope with)
    # it will not return the line expected above, nor
    # will it generate a ".dao" file, be nice in such cases
    # tjt 3-2011
    if { $sffile == "error" } {
	report "* Image is hopeless.\n"
    } else {
	average $sffile
	show_spot_count $sffile
    }
}

# centroid and average a comma-sep'd list of FITS images. 
# XXX - there is also a proc centroid later in this file
# that does essentially the same thing, these should be combined.
msg_register WFSSERV centroid
proc WFSSERV.centroid { s sock msgid cmd list } {
    global bin_dir env systemFile rotangle rotangle_def fmode

    if {![file exists "uparm"]} {eval exec mkdir uparm}

    puts "MSG call to centroid routine: $list"

    do_centroid $list

    msg_ack $sock $msgid
}

#------------------------------------------------------------------------

if {$fmode != "MMIRS" && $debug != "postmortem"} {
    # look for auto WFS gui
    set autowfs "$env(WFSROOT)/auto_correct_gui"
    if {[file exists $autowfs]} {
	exec $autowfs $fmode $inst &
    }
}

#------------------------------------------------------------------------

#set up stuff for aberration display/manipulation.
set ABER [toplevel .aber] 
wm geometry .aber 350x610+610+355
wm title $ABER "Wavefront Zernikes (nm)"
wm title . "$fmode SHWFS"

set ZPOLY 19
#define names for the displayed zernike coefficients
set zt " 0 tilt_yax tilt_xax defocus astig_45 astig_0 Xcoma Ycoma \ 
		spherical tref_bsX tref_bsY ast5th_45 ast5th_0 Frth_1 Frth_2 \
		tref5th_X Tref5th_Y Xcoma5th Ycoma5th spher6th"

set ztable [frame $ABER.ztable]
set zactions [frame $ABER.actions]

set PF $zactions.pf
set axfor $zactions.axfor
set shzrn $zactions.shzrn
set pup_PSF $zactions.pup_psf

# set up zernike coefficient entries, labels, and check buttons

for {set i 1} {$i <= $ZPOLY} {incr i} {
    checkbutton $ztable.${i}c -text "z$i :" -onvalue "1" -offvalue "0" \
	-variable z$i -width 5
    if {$i < 4} {set z$i 0} else {set z$i 1}; # deselect tilts and defocus
    if {$i == 19} {set z$i 0};     # deselect high order spherical
    label $ztable.${i}l -width 9 -text [lindex $zt $i]
    entry $ztable.${i}e -width 8 -font fixed -text [lindex $zt $i] 
}

#set up zernike combined aberrations
entry $ztable.tilt -width 14 -justify right -text tot_tilt
entry $ztable.focus -width 14 -justify right -text focus_um
entry $ztable.astig -width 14 -justify right -text tot_astig
entry $ztable.coma -width 14 -justify right -text tot_coma
entry $ztable.trefoil -width 14 -justify right -text tot_trefoil
entry $ztable.ashtray -width 14 -justify right -text tot_ashtray
entry $ztable.4th -width 14 -justify right -text tot_4th
entry $ztable.hitre -width 14 -justify right -text tot_hitre

#set up frame to contain logfile file name
set logname [frame $ABER.logname]
label $logname.ofilel -width 15 -text "Log file name:"
entry $logname.ofilee -width 20 -text lfile
set lfile "default.log" ; # default log file

#set up a frame to control a zernike coeff log file
set logframe [frame $ABER.logframe]
label $logframe.comml -width 15 -text "entry comment:"
entry $logframe.comme -width 20 -text ecomm

# set up frame for manual M1/M2 corrections
set correctfrm [frame $ABER.correctframe]
set m2 [button $correctfrm.m2 -text "Correct Coma" -bg red \
	    -command {m2correct}]
set m2foc [button $correctfrm.m2foc -text "Correct Focus" -bg red \
	    -command {m2focus}]

# set reference focu frame
set focfrm [frame $ABER.reffocus]
set m1 [button $focfrm.m1 -text "Correct Primary" -bg red \
	       -command {m1correct}]
set cenbut [button $focfrm.foc_b -text "Center Image" -bg red \
		-command {recenter}]

#------------------------------------------------------------------------

#define the directory of centroid_list() and ihaverage().
set CENHOME $bin_dir ; # no longer used since everything is in one directory
set AVHOME $bin_dir   ; # same comment

set RAD1 57.2958

# filter is used to detect the file state of the GUI, and also to then decide
# what actions can and cannot be done.
# These days it is ALWAYS "fits", the old default was "*"

set filter "fits"
set last_filter $filter

#Area for defining frames
frame .wfs -relief ridge -borderwidth 10 

frame $AVC -relief groove -borderwidth 5
frame $AVC.f1  -relief  sunken -borderwidth 2
frame $AVC.f2
frame $AVC.f3
frame $AVC.f4

frame .wfs.gen -border 1 -relief groove -borderwidth 5

#-----------------------------------------------------------------------
# set up window for displaying the pupil, psf, and act force xpm images

set wim [toplevel .wim]
wm geometry .wim 630x655+0+0
#set xpmimg [canvas $wim.xpms -height 300 -width 650 -bg lightyellow \
#		-relief sunken -borderwidth 5]
set xpmimg [canvas $wim.xpms -height 300 -width 450 -bg lightyellow \
		-relief sunken -borderwidth 5]

#create the places for the xpm images in the canvas
$xpmimg create image 110 150 -tag pmap
$xpmimg create image 310 150 -tag psfmap
#$xpmimg create image 510 150 -tag actmap

#label the canvas
$xpmimg create text 430 150 -text "+Y (N)" 
$xpmimg create text 225 290 -text "+X (E)"
$xpmimg create text 110 20 -text "Pupil"
$xpmimg create text 310 20 -text "PSF"
#$xpmimg create text 510 20 -text "Act Forces"

#set up entries to control psf image generation
set xpmpsf [frame $wim.psfent]

# add entry for detector shift um
entry $xpmpsf.ds -text DS -width 5 
label $xpmpsf.dsl -text " +/-Det um:"
set DS 0

# add entry for CCD field size (um) 
entry $xpmpsf.fld -text FIELD -width 5
label $xpmpsf.fldl -text "Field \":"
set FIELD .5

#add entry for display range % (display psf from min to range*max)
entry $xpmpsf.rng -text RNG -width 5
label $xpmpsf.rngl -text "Range %:" -width 8
set RNG 25
	
#Create frame for rms plot and actuator force text window
set wframe [frame $wim.w1 -borderwidth 5 -relief raised]

#create single column scrolling text window for actuator force values
set frclist [tixScrolledListBox $wim.forces -scrollbar y] 

#set pointer to the listbox 
set fbox [$frclist subwidget listbox]
$fbox configure -height 15 -width 15

#Create barchart for displaying relative rms phase errors.
set G2 [blt::barchart $wframe.rms -height 3i -width 5i] 
set rmsLabels {Tilt Def Astig Coma Sph3 Trefoil Astig5th Quadrafoil \
		   Tref5th Coma5th Sph6th Selected}
set labelPos {1 2 3 4 5 6 7 8 9 10 11 13}
set labelColors {purple blue1 blue4 green1 green4 red1 red4 orange1 yellow \
		     orange4 brown black} 

#create elements for the rms zernike phase values
for {set i 0} {$i<12} {incr i} {
    $G2 element create [lindex $rmsLabels $i] -xdata [lindex $labelPos $i] \
	-foreground [lindex $labelColors $i] -ydata $i 
}

#set up the actuator numbering sequence
set actN ""
for {set i 1} {$i <= 52} {incr i} {
    set actN [linsert $actN end $i] 
}
for {set i 101} {$i <= 152} {incr i} {
    set actN [linsert $actN end $i] 
}

#sets up labels for plotting rms phase values
proc bar2phases { } {
    global G2 rmsLabels labelPos labelColors
    $G2 configure -title "Wavefront Errors" -height 3i
    $G2 xaxis configure -title "Mode"
#    $G2 yaxis configure -title "RMS Phase Error (nm)" -max 500
}


#-----------------------------------------------------------------------

label $AVC.name -text "Centroid, Average, and Find Aberrations" 
$AVC.name configure -fg blue

button .wfs.gen.ex -text "Exit" -command {exit}
entry .wfs.gen.sys -width 30 -text systemFile

# switch $fmode {

#     F9 { set systemFile "$env(WFSROOT)/f9newsys.cntr"; # uses new shcenfind
# 	                                               # magnification scheme
#     }
#     F5 { set systemFile "$env(WFSROOT)/f5sysfile.cntr"; # uses new shcenfind 
#                                                         # magnification scheme
#     }
#     MMIRS { set systemFile "$env(WFSROOT)/mmirs_wfsc2_sysfile.cntr"; # uses new shcenfind 
#                                                                # magnification scheme
#     }

# }

# Note that the "system file" is the set of reference spots for
# whatever lenslet array is being used.
set systemFile "ref.dat"

label .wfs.gen.sysname -text "System File:"

#two radio buttons to set the solve mode.  "modes" uses gradients and ONLY
#looks at data that fits a zernike mode.  "phases" uses phases contributed
#by all sources and is the highest diagnostic mode we have (at the cost of
#great time in doing the initial SVD for each data set).  In practice, use
#"modes" for quick looks and for the initial force optimizations, then use
#"phases" to take out the last errors or find errors that don't correspond
#to a zernike mode.  Also remember that gradients are averages over 4
#adjacent hartmann apertures, while phases solve for each individual
#hartmann aperture.

#frame .wfs.gen.md
#radiobutton .wfs.gen.md.grd -text "modes" -variable slv_mode -value "0" -anchor w
#radiobutton .wfs.gen.md.phs -text "phases" -variable slv_mode -value "1" -anchor w
#set solve mode to zernike terms only using averaged gradient data
set slv_mode 0

#set up a entry widget that shows selected working directory
tixLabelEntry $AVC.f1.dirlabel -label "Directory:" -labelside top \
    -options {
	entry.width 30
	entry.textVariable "" 
    }

#Set pointer to the entry widget --
# dshow points to the current working directory.
set dshow [$AVC.f1.dirlabel subwidget entry]

#set up a scrolling listbox for showing files
# tixScrolledListBox $AVC.f2.files 

#set pointer to the listbox and set for multi discontinous selections
# set lbox [$AVC.f2.files subwidget listbox]
# $lbox configure -selectmode extended

# Testing using a listbox directly, instead of a tixScrolledListbox.  JDG  5-28-2010
#set lbox [listbox $AVC.f2.files -selectmode extended]
set lbox [listbox $AVC.f2.files -selectmode extended -yscrollcommand "$AVC.f2.ttscroll set"]

# tjt 2-16-2011 - Sure would be nice to have a scrollbar on this,
# so lets try to add one (without dragging in Tix)
# Note that the scrollbar is not strictly necessary.
# The listbox can be manipulated directly just using the
# mouse wheel or other mouse contortions.
# But a scrollbar makes it much more obvious what is going on.
scrollbar $AVC.f2.ttscroll -command "$AVC.f2.files yview"
	
#and the procedure to call it
proc dirselect { } {
    global AVC
    $AVC.dirpick popup
}
	
#set up a radio button for selecting the file filter 
label $AVC.f3.name -text "Filters" 
radiobutton $AVC.f3.fits -text ".fits" -variable filter \
    -value "fits" -anchor w
radiobutton $AVC.f3.ref -text "Ref*.fits" -variable filter \
    -value "ref" -anchor w
radiobutton $AVC.f3.ctr -text ".cntr" -variable filter \
    -value "cntr" -anchor w
radiobutton $AVC.f3.all -text "*.*" -variable filter \
    -value "*" -anchor w
radiobutton $AVC.f3.aver -text ".av" -variable filter \
    -value "av" -anchor w
radiobutton $AVC.f3.zrn -text ".zrn" -variable filter \
    -value "zrn" -anchor w

#create scrolling text widget for reporting progress, etc.
set txt [frame .wfs.t]
set reptxt $txt.tx
text $reptxt -height 5 -width 45 -yscrollcommand "$txt.v_scroll set" \
    -bg lightyellow
scrollbar $txt.v_scroll -command "$reptxt yview"

proc report {stmt} {
    global reptxt
    $reptxt insert end $stmt
    $reptxt see end
    update
    set date [clock format [clock seconds] -format "%Y%m%d %H:%M:%S GMT" -gmt true]
    set fid [open report.log a]
    puts $fid "$date: $stmt"
    close $fid
}

#---------------------------------------------------------------------
#Procedures

# Filter and show files
# tjt modified this so it only updates the listbox when it
# sees new files appear.  It does this based on a count of
# files, so this could be tricked if files were deleted and
# then new ones added (which we do not expect to happen).
# Note that we could be clever and figure out which new files
# had appeared and just add those rather than nuking the listbox
# and loading it up from scratch, but it isn't worth the bother.

proc filterFiles {} {
    global dshow
    global lbox
    global slv_mode
    global filter
    global last_files
    global first

    cd [$dshow get]
    set files [lsort [glob -nocomplain *.$filter]]

    if { [llength $files] == [llength $last_files] } {
    	return
    }
    set last_files $files
    if { ! $first } {
	report " New Files detected\n"
    }

    $lbox delete 0 end

    # check to see which zernike file set to display.
    if {$filter == "ref"} {
	set files [lsort [glob -nocomplain Ref*.fits]]
    }

    if {$slv_mode == 1 && $filter == "zrn"} { 
	set files [lsort [glob -nocomplain *.zph]]
    }

    if { $files != ""} {
	foreach filename $files {
	    # tjt - ignore some files we just don't care about.
	    if { $filename == "back.fits" } continue
	    if { $filename == "tmp.fits" } continue
	    $lbox insert 0 $filename 
	}
    }
}

# Color action buttons to help user...
# tjt thinks using -state disabled/enabled would be even better

proc colorButtons {} {
    global filter
    global AVC

    #color them all grey first
    $AVC.f4.centroid configure -bg lightgrey
    $AVC.f4.average configure -bg lightgrey
    $AVC.f4.zernike configure -bg lightgrey
    $AVC.f4.ref configure -bg lightgrey
    $AVC.f4.system configure -bg lightgrey 

    if {$filter=="fits"} {
	#$AVC.f4.centroid configure -bg green
	$AVC.f4.centroid configure -bg pink
    }

    if {$filter == "ref"} {
	$AVC.f4.ref configure -bg green
    }

    if {$filter=="cntr"} {
	$AVC.f4.average configure -bg green
	$AVC.f4.zernike configure -bg green
	$AVC.f4.system configure -bg green
    } 

    if {$filter=="av"} {
	$AVC.f4.zernike configure -bg green
	$AVC.f4.system configure -bg green
    } 
}

proc update_files {} {
    global first
    global filter
    global last_filter
    global lbox

    if { $filter != $last_filter } {
    	set last_files {}
	$lbox delete 0 end
	set last_filter $filter
    }

    filterFiles
    if { ! $first } { colorButtons }
}
		
#set radiobutton filter action
button $AVC.f3.reload -text "Reload" -command update_files

# Fill in the Tix labelentry subwidget with directory name
# This gets called on startup (usually the only time this
# gets called) or when the directory is changed.

proc setpath {dir} {
    global dshow

    $dshow delete 0 end
    $dshow insert 0 $dir

    update_files
}

# set the system file interferogram.  Must be a .cntr file (not yet checked
# for). Use lindex to guard against multiple selections (pick the first
# only).  Then set the systemFile entry widget with the result.

proc setSystemFile { } {
    global systemFile lbox filter

    if {$filter != "av" && $filter != "cntr"} {
	report "* Wrong file type for system file.\n"
	return
    }
		
    set sysf [$lbox curselection]
    set systemFile [$lbox get [lindex $sysf 0]]
}

# ----------------------------------------------------------------
#centroid organizes and shuttles files to the external centroid routine.  It
#tests to make sure the file state is appropriate (ie filter=fits), then
#calls the c centroid routine for each selected file, and finally renames
#the centroided fits file to mask it from the file display 
#
# added a mode parameter to differentiate between centroiding reference
# images and data images. TEP 4-17-2003
# the mode parameter is no longer used TJT 1-24-2011
#proc centroid {mode} { 

proc centroid {} { 
    global filter lbox CENHOME reptxt bin_dir env systemFile rotangle rotangle_def fmode
    
    if {![file exists "uparm"]} {eval exec mkdir uparm}

    set cur_dir [exec pwd]
    puts "centroid routine changing directory to: $cur_dir"

    #send the files one at a time to the centroid routine--then rename.
    #Remember that info selection returns indices--not filenames.

    set list ""
    foreach fileindex [$lbox curselection] {
	set filename [$lbox get $fileindex]	
	puts "centroid routine processing: $filename"
	if {$list == ""} {
	    set list $filename
	} else {
	    set list "$list,$filename"
	}
    }

    if { $list == "" } {
    	puts "No files selected for centroiding"
	report "No files selected for centroiding\n"
	return
    }

    puts "Centroid these files: $list"
    do_centroid $list

    #now refresh the GUI files listbox
    update_files
}

# ----------------------------------------------------------------
#Average() sends a list of files to be averaged to ihaverage().  The final
#file has an extension ".av".  $filter must be set only to cntr for this
#routine to be activated.

proc average { passlist } {
    global AVHOME reptxt curr_xcen curr_ycen fmode

    puts "proc average called with: $passlist"

    # set the average list to that determined from centroid()
    set avlist $passlist

    report "* Averaging list: $avlist\n"
    set ttt [exec pwd]
    report "* pwd is $ttt\n"

    puts "files sent to ihaverage: $avlist"

    switch $fmode {
	F9 { eval exec "$AVHOME/ihaverage $avlist" }
	F5 { eval exec "$AVHOME/ihaverage_f5 $avlist" }
	MMIRS { eval exec "$AVHOME/ihaverage_mmirs $avlist" }
    }

    report "* Done Averaging--> [lindex $avlist 0].av\n"

    # reproduce the name of the output file from ihaverage()
    # This is passed to zernike()--first cen file + .av
    set avfile "[lindex $avlist 0].av"

    # find the ave center and make it global for the spot centering routine
    set fid [open $avfile r]
    set tmp [read $fid]
    close $fid

    set line [lindex [split $tmp \n] 1]
    set curr_xcen [lindex $line 4]
    set curr_ycen [lindex $line 5]

    zernike $avfile
}

#ref_average() sends a list of files to be averaged to ihaverage().  The final
#file has an extension ".av".  $filter must be set only to cntr for this
#routine to be activated.
# tjt - never used.

proc ref_average {passlist} {
    global AVHOME reptxt systemFile fmode

    # set the average list to that determined from centroid()
    set avlist $passlist

    # reproduce the name of the file output by ihaverage() to pass to
    # zernike()--first cen file + .av
    set avfile "[lindex $avlist 0].av"

    report "* Averaging list: $avlist\n"
    set ttt [exec pwd]
    report "* pwd is $ttt\n"
    switch $fmode {
	F9 { eval exec "$AVHOME/ihaverage $avlist" }
	F5 { eval exec "$AVHOME/ihaverage_f5 $avlist" }
	MMIRS { eval exec "$AVHOME/ihaverage_mmirs $avlist" }
    }

    report "* Done Averaging--> [lindex $avlist 0].av\n"

    set systemFile $avfile
}

# recenter takes the rotangle and center for the latest data that's been
# centroided and moves either the hexapod or mount to center the spot
# image on the CCD frame.

proc recenter { } {
    global rotangle rotangle_def xcenter ycenter curr_xcen curr_ycen RAD1 fmode m2_gain

    set tok [dns::resolve _hexapod._tcp.mmto.arizona.edu -type SRV]
    set res [dns::result $tok]
    set port [lindex [lindex [lindex $res 0] 11] 5]
    set host [lindex [lindex [lindex $res 0] 11] 7]

    set x [expr $curr_xcen - $xcenter]
    set y [expr $curr_ycen - $ycenter]

    set dist [expr hypot($x, $y)]
    set angle [expr atan2($y, $x)]

    set derot_ang [expr (180 + 2*$rotangle_def - $rotangle)/$RAD1 + $angle]

    switch $fmode {
	F9 {
	    set az [format "%5.1f" [expr $m2_gain*-1*$dist*cos($derot_ang)*0.12]]
	    set el [format "%5.1f" [expr $m2_gain*$dist*sin($derot_ang)*0.12]]
	}
	F5 {
	    set az [format "%5.1f" [expr $m2_gain*$dist*cos($derot_ang)*0.135]]
	    set el [format "%5.1f" [expr $m2_gain*-1*$dist*sin($derot_ang)*0.135]]
	}
	MMIRS {
	    set az 0.0
	    set el 0.0
	}
    }

    report "* Moving hexapod $az\" in Az and $el\" in El\n"

#    catch {msg_cmd HEXSERV "tiltxerr_zc $el" 20000}
#    catch {msg_cmd HEXSERV "tiltyerr_zc $az" 20000}

    catch {exec echo "offset_zc wfs tx $el" | nc -w 5 $host $port}
    catch {exec echo "offset_zc wfs ty $az" | nc -w 5 $host $port}
    catch {exec echo "apply_offsets" | nc -w 5 $host $port}
}

#proc zernike provides for batch solving of Zernike polynomials and
#[optionally] phases. A list of stellar integerograms are batch-solved
#against a system reference (given by the systemFile entry). NOTE: this
#routine needs a solve-state of 0 or 1 aappended to each call (1 means solve
#for phases too).

# Called from "average" and when the "Aberr" button is pushed.

proc zernike {avfile} {
    global systemFile AVHOME reptxt slv_mode rotangle fmode

    # this is by default "ref.dat" these days
    if {$systemFile == "Not yet selected"} {
	report "* No system file is selected.\n"
	return
    }

    # Note that slv_mode is appended:
    #	0 = mode solve only (gradients),
    #	1= raw phase solve.
	
    set filename $avfile
    report "* Finding aberrations for $filename\n"

    #switch $fmode {
#	F9 { eval exec "$AVHOME/getZernikesAndPhases $systemFile $filename $slv_mode $rotangle" }
#	F5 { eval exec "$AVHOME/getZernikesAndPhases_f5 $systemFile $filename $slv_mode $rotangle" }
#	MMIRS { eval exec "$AVHOME/getZernikesAndPhases_mmirs $systemFile $filename $slv_mode $rotangle" }
#    }

    switch $fmode {
	F9 { set cmd "$AVHOME/getZernikesAndPhases" }
	F5 { set cmd "$AVHOME/getZernikesAndPhases_f5" }
	MMIRS { set cmd "$AVHOME/getZernikesAndPhases_mmirs" }
    }

    puts "Run command: $cmd $systemFile $filename $slv_mode $rotangle"
    puts [exec $cmd $systemFile $filename $slv_mode $rotangle]

    report "* linked spots: [eval exec wc -l link]\n"
    report "* Aberration routines finished.\n"

    set zrnfile "${avfile}.zrn"	

    showzerns $zrnfile
}

proc clear_forces { } {

#   exec /mmt/bin/rcell -c
    exec /mmt/scripts/cell_clear_forces

    set tok [dns::resolve _hexapod._tcp.mmto.arizona.edu -type SRV]
    set res [dns::result $tok]
    set port [lindex [lindex [lindex $res 0] 11] 5]
    set host [lindex [lindex [lindex $res 0] 11] 7]

    exec echo "offset m1spherical z 0.0" | nc -w 5 $host $port
    exec echo "apply_offsets" | nc -w 5 $host $port

    report "* Forces cleared.\n"
}
		
# Set up a Tix popup directory selection box and proc to pass selection to.
# This runs immediately on starting the script and gets loaded with whatever
# directory you are in when you invoke ihwfs.tcl.
# When this proc gets called, it also loads up the file listbox

option add *Background grey widgetDefault

tixDirSelectDialog $AVC.dirpick -command setpath

button $AVC.f1.dir -text "Set Directory" -command dirselect

#set up action buttons for the AVC frame

# tjt - this label looks like a button, confusing, ditch it.
##label $AVC.f4.name -text "Action"

button $AVC.f4.centroid -text "Centroid" -command {centroid}

set ancient disabled
if { $ancient == "disabled" } {
    button $AVC.f4.average -text "Average" -state disabled -command {average [$lbox get [$lbox curselection]]}
    button $AVC.f4.zernike -text "Aberr" -state disabled -command {zernike [$lbox get [$lbox curselection]]}
    button $AVC.f4.system -text "Set System" -state disabled -command {setSystemFile}
} else {
    button $AVC.f4.average -text "Average" -command {average [$lbox get [$lbox curselection]]}
    button $AVC.f4.zernike -text "Aberr" -command {zernike [$lbox get [$lbox curselection]]}
    button $AVC.f4.system -text "Set System" -command {setSystemFile}
}

button $AVC.f4.ref -text "Clear Forces" -command {clear_forces}

# a choice was offered 4/2011 before we were sure about this.
# checkbutton $AVC.f4.tom -text "New Algorithm" -variable toms_mode

#---------------------------------------------------------------------
#plotting facilities

#getFileData opens and reads the first two columns of a data file.  It
#ignores comment and blank lines.

proc getFileData {file} {
    global x y xoff yoff mag
    puts $file
    set fid [open $file "r"]

    #find and store the magnification and interferogram offset data. This
    #breaks if the magnification line doesn't exist.  It's expecting:
    # "# X xmag ymag xoff yoff".
    while { [eof $fid] != 1 } {	
	gets $fid data
	if {[regexp {# X} $data] == 1} {
	    puts "found the mag ID line"
	    set mag [expr ([lindex $data 2] + [lindex $data 3])/2]
	    set xoff [lindex $data 4]
	    set yoff [lindex $data 5] 
	    break
	}
    }

    #reset file to beginning
    seek $fid 0 

    #now get xy pairs
    set lcntr 0
    set x ""
    set y ""
    # 9-00 eof is not working properly--saved by llength catch at last line!
    while { [eof $fid] != 1 } {
	gets $fid data
	if {[llength $data] == 0 || [regexp # $data] == 1} {
	    continue
	}
	set x [concat $x [lindex $data 0]]
	set y [concat $y [lindex $data 1]]
	set lcntr [expr $lcntr + 1] 
    }

    close $fid

}
#----------------------------------------------------------------------
#----------------------------------------------------------------------
#dynamic zoom for the barchart widget--someday need to write a general tool
#where the code is re-used for various widgets.
proc barZoomIn {x0 y0 x1 y1} {
    global G2
    if {($x0 == $x1) || ($y0 == $y1)} {
	return 
    }

    if { $x0 > $x1 } {
	$G2 xaxis configure -min $x1 -max $x0 
    } elseif { $x0 < $x1} {
	$G2 xaxis configure -min $x0 -max $x1 
    }
    
    if {$y0 > $y1} {
	$G2 yaxis configure -min $y1 -max $y0 
    } elseif {$y0 < $y1} {
	$G2 yaxis configure -min $y0 -max $y1 
    }
}

bind $G2 <ButtonPress-1> { barSelectStart %x %y }
bind $G2 <B1-Motion> { barselectMove %x %y }
bind $G2 <ButtonRelease-1> { barSelectEnd %x %y }

proc barGetCoords { scrX scrY xVar yVar} {
    global G2
    upvar $xVar x
    upvar $yVar y
    set coords [$G2 invtransform $scrX $scrY]
    set x [lindex $coords 0]
    set y [lindex $coords 1] 
}

proc barSelectStart {x y} {
    global x0 y0
    barGetCoords $x $y x0 y0
    barCreateRectangle 
}

proc barselectMove {x y } {
    global x0 y0
    barGetCoords $x $y x1 y1
    barDrawRectangle $x0 $y0 $x1 $y1 
}

proc barSelectEnd {x y} {
    global x0 y0
    barGetCoords $x $y x1 y1
    barDestroyRectangle 
    barZoomIn $x0 $y0 $x1 $y1 
}

proc barCreateRectangle { } {
    global G2
    $G2 marker create line -name "ZoomRegion" \
	-dashes { 4 2 } 
}

proc barDrawRectangle { x0 y0 x1 y1 } {
    global G2
    $G2 marker configure "ZoomRegion" \
	-coords { $x0 $y0 $x1 $y0 $x1 $y1 $x0 $y1 $x0 $y0 } 
}
	
proc barDestroyRectangle { } {
    global G2
    $G2 marker delete "ZoomRegion" 
}

proc barZoomOut { } {
    global G2
    $G2 xaxis configure -min "" -max ""
    $G2 yaxis configure -min "" -max "" 
}

bind $G2 <ButtonRelease-3> barZoomOut

$G2 crosshairs off

bind $G2 <Motion> {
    $G2 crosshairs configure -position @%x,%y 
}

#---------------------------------------------------------------------
#---------------------------------------------------------------------
# aberration display/manipulation routines

# draw_pupil redraws the pupil phase map using the selected Zernikes which
# are given by a 0,1 string mask with ZPOLY characters. It works in two
# modes.  It displays a continuous mapping if slv_mode==0, and shows
# discrete phases if slv_mode==1. In either case, only those modes that are
# selected with the zernike radiobuttons are displayed.  In the case of
# slv_mode==1, those modes AND the residual phases are displayed in the XPM
# image.

proc draw_pupil {zfile mask} {
    global AVHOME slv_mode G2 rmsLabels DS FIELD RNG rms_calc act_forces \
	pmap psfmap xpmimg fmode
		
    report "* $zfile $mask\n"

    if {$slv_mode == 0} {
	#eval exec "$AVHOME/pup_psf $zfile $mask"
	#I need a catch for mask = 00000000 since the XPM creator doesn't
	#like a constant phase in the image.
	eval exec "touch $zfile"
	switch $fmode {
	    F9 { set command "$AVHOME/pup_psf $zfile $mask $DS $FIELD $RNG $rms_calc" }
	    F5 { set command "$AVHOME/pup_psf_f5 $zfile $mask $DS $FIELD $RNG $rms_calc" }
	    MMIRS { set command "$AVHOME/pup_psf_mmirs $zfile $mask $DS $FIELD $RNG $rms_calc" }
	}
	report $command\n
	set fid [open |$command r]
	set results [read $fid]
	close $fid
    }

    # this should never, ever get used. slv_mode should always be 0
    if {$slv_mode == 1} {
	# construct the filename with the xy,phase info
	set ff [split $zfile .]
	set ff [join [lreplace $ff end end phs] .]
	report "* Accessing file $ff\n"
	switch $fmode {
	    F9 { set command "$AVHOME/pup_discretePhs $ff $zfile $mask $DS $FIELD $RNG $rms_calc" }
	    F5 { set command "$AVHOME/pup_discretePhs_f5 $ff $zfile $mask $DS $FIELD $RNG $rms_calc" }
	    MMIRS { set command "$AVHOME/pup_discretePhs_mmirs $ff $zfile $mask $DS $FIELD $RNG $rms_calc" }
	}
	report $command\n
	#eval exec $command
	set fid [open |$command r]
	set results [read $fid]
	close $fid
    }
		
    report $results\n ; # report rms phase errors for selected modes

    # Tix allows XPM images as type pixmap
    image create pixmap pup_map -file wavefront.xpm
    $xpmimg itemconfigure pmap -image pup_map
    image create pixmap psf_map -file psf.xpm
    $xpmimg itemconfigure psfmap -image psf_map

    # update all mode rms's in barchart
    if {$rms_calc == 0} {
	bar2phases
	for {set i 1} {$i<12} {incr i} {
	    $G2 element configure [lindex $rmsLabels $i] -ydata \
		[lindex $results $i] -hide 0
	}
    }

    # update only the selected mode rms
    if {$rms_calc == 1} {
	$G2 element configure [lindex $rmsLabels 11] -ydata $results	
    }

    set rms_calc 1

}

#-------------------------------------------------------------------

# showzerns simply reads the first .zrn  (or .zph) file selected in the file
# box, and displays the coefficients into the $ztable window
# 6-11-02: changed to read a passed zernike file and added M2
# collimation/focus correction calculations

proc showzerns {zrnfile} {
    global ZPOLY zt RAD1 zfile mask rms_calc thetax thetay theta_CC \
	focus_nm tilt_x tilt_y cenbut spher ref_focus_nm ref_spher_nm \
	defoc_fact fmode focus_um

    set zfile $zrnfile
    report "* Displaying Zernike coeffs for $zfile.\n"

    # read in the zernike coefficient vector from selected file. NOTE: data
    # reads in zero-based while zernikes are 1-based. Don't confuse $zfile
    # (which is the zernike coeff file) with *zfile* which is the hardwired
    # file name that always contains the most recent force corrections.

    set fid [open $zfile r]
    set data [read $fid]
    close $fid
    #add dummy entry at beginning of list-- linsert returns entire new list
    set data [linsert $data 0 0]

    # write a zernfile with ref focus subtracted
    regsub {av.zrn} $zfile {sub.zrn} zfile
    set fid [open $zfile w]

    set nzero 0
    set nfcked 0 

    for {set i 1} {$i <= $ZPOLY} {incr i} {
	upvar #0 [lindex $zt $i] coeff
	upvar #0 z$i button
	set val [lindex $data $i]

	# check for all zeros (f*cked fit)
	if {$val == 0.0} {
	    incr nzero
	}

	# check for huge numbers (f*cked fit)
	if {$i > 3 && $val > 2500.0} {
	    incr nfcked
	}

	if {$i == 3} {
	    set coeff [format "%15.7f" [expr $val-$ref_focus_nm]]
	} elseif {$i == 8} {
	    if {$val == 0.0} {
		set spher 0.0 
	    } else {
		set spher [expr $val-$ref_spher_nm]
	    }
	    set coeff [format "%15.7f" $spher]
	} else {
	    set coeff [format "%15.7f" $val]
	}
	puts $fid $coeff
	if {$i == 3} {
	    set coeff [format "%7.0f" [expr $val-$ref_focus_nm]]
	} elseif {$i == 8} {
	    set spher [expr $val-$ref_spher_nm]
	    set coeff [format "%7.0f" $spher]
	} else {
	    set coeff [format "%7.0f" $val]
	}
	if {abs($coeff) < 150} {set button 0}
	if {abs($coeff) > 150 && $i != 19 && $i > 3} {set button 1}
	if {abs($coeff) > 1500 && $i == 8} {set button 0}
	if {abs($coeff) > 1000 && $i > 8} {set button 0}
	if {$i > 10 && $fmode == "MMIRS"} {set button 0}

	if {$val == 0.0} {
	    set button 0
	    set coeff 0.0
	}
	report "$coeff" ; # send zernikes to report 1 by 1
    }
    close $fid

    report "\n"
    if {$nzero > 7 || $nfcked > 5} {
	report "Zernike fit failed.\n"
	return
    }

    #Calc totals of non-axisymmetric terms
    set a1 [lindex $data 1]
    set a2 [lindex $data 2]
    set tlt [expr hypot($a1, $a2)]
    #reverse angle args since this is about an axis
    set tltang [expr {atan2($a1,$a2) * $RAD1}]
    upvar #0 tot_tilt ta
    set ta [format "%5.0f @ %3.1f°" $tlt $tltang]

    set a1 [lindex $data 4]
    set a2 [lindex $data 5]
    set ast [expr hypot($a1, $a2)]
    set astang [expr { atan2($a1,$a2) * $RAD1 / 2}]
    upvar #0 tot_astig ta
    set ta [format "%5.0f @ %3.1f°" $ast $astang]
    
    set a1 [lindex $data 6]
    set a2 [lindex $data 7]
    set coma [expr hypot($a1, $a2)]
    set comaang [expr {atan2($a2,$a1) * $RAD1}]
    upvar #0 tot_coma ta
    set ta [format "%5.0f @ %3.1f°" $coma $comaang]

    set a1 [lindex $data 9]
    set a2 [lindex $data 10]
    set tre [expr hypot($a1, $a2)]
    set treang [expr {atan2($a2,$a1) * $RAD1 / 3}]
    upvar #0 tot_trefoil ta
    set ta [format "%5.0f @ %3.1f°" $tre $treang]

    set a1 [lindex $data 11]
    set a2 [lindex $data 12]
    set ash [expr hypot($a1, $a2)]
    set ashang [expr {atan2($a2,$a1) * $RAD1 / 4}]
    upvar #0 tot_ashtray ta
    set ta [format "%5.0f @ %3.1f°" $ash $ashang]

    # calculate the M2 corrections
    set xcoma [lindex $data 6] ; set ycoma [lindex $data 7]
    set focus_nm [lindex $data 3]
    set tilt_x [lindex $data 2]
    set tilt_y [lindex $data 1]

    upvar #0 focus_um foc
    if {$focus_nm == 0.0} {
	set focus_um 0.0
    } else {
	set focus_um [expr ($focus_nm-$ref_focus_nm)/$defoc_fact]
    }
    set foc [format "%5.0f um" $focus_um]

    $cenbut configure -bg green; # ok to set ref focus now

    # rescaling for rotation about center of curvature (TEP 3-21-03)
    set thetax [format "%4.1f" [expr -$xcoma/$theta_CC]] 
    set thetay [format "%4.1f" [expr -$ycoma/$theta_CC]]

    # rms_calc is a switch which determines whether or not pupil phase rms's
    # are calculated when pup_psf or pup_discretePhs are run.  Reset to zero
    # each time a new zernike file set is loaded or the barchart is
    # overwritten by the BCV axial force calculations.
    
    set rms_calc 0

    createMask

    draw_pupil $zfile "0001111111111111111"

    modeAxialForces ; # calculate force corrections

    AddLogEntry ; # add zernike coefficients to log file

}

# Interactive entrance to show zerns.  Made so you can select zernike files
# from the listbox and view/process them without having to do all the other
# automated stuff like centroiding and calculating aberrations.  In other
# words, this provides a way to view files for which all the calcs are
# already finished.
proc showzernsInt { } {

    global lbox filter

    if {$filter != "zrn"} {
	report "* wrong file type for zernike display\n"
	return
    }
	
    set zindx [$lbox curselection]
    # accept only first file even if multiples are selected
    set zfile [$lbox get [lindex $zindx 0]]

    showzerns $zfile ; # call the normal routine for displaying zernikes
}

#-------------------------------------------------------------------
# provides support for storing zernike coefficents in a log file.
proc AddLogEntry { } {
 
    global ZPOLY zt lfile ecomm zfile rotangle

    # file doesn't exist, so put in zernike titles
    if ![file exists $lfile] {
	set fid [open $lfile w]
	set titles "# "
	for {set i 1} {$i <= $ZPOLY} {incr i} {
	    append titles [format "%10s" [lindex $zt $i]] 
	}
	puts $fid $titles
	close $fid
	report "* Added zernike labels to $lfile.\n"
    }

    #if file exists, append comments and data
    set data ""
    for {set i 1} {$i <= $ZPOLY} {incr i} {
	upvar #0 [lindex $zt $i] coeff
	append data [format "%10d" $coeff]
    }

    set fid [open $lfile a]
    puts $fid "# $zfile (Rotation = $rotangle): $ecomm"
    puts $fid $data
    close $fid
    report "* Added zernike coefficients to $lfile.\n"
    report "-----------------------------\n"
    report "\n"

}

# send force correction file (always called zfile) to cell crate
proc m1correct { } {

    global BENDMIRROR zt z3 z8 defoc_fact spher m1_gain
    global zfile

    # make sure forces are recalculated!!!
    modeAxialForces

    # get the spherical to calc any defocus that needs to be compensated
    # for from using the cone-mode to correct spherical
    set spher_button $z8
    set defoc_button $z3

    if {$BENDMIRROR} {

	#set forcefile zfile
	regsub {.zrn} $zfile {.forces} forcefile

	#set command "/mmt/bin/rcell -z < $forcefile 2>1"
	set command "/mmt/scripts/cell_send_forces $forcefile"
	#eval exec $command
	set fid [open |$command r]
	set data [read $fid]
	close $fid
	puts "$data"
	report "* cell forces : $data \n"

	if {$spher_button == 1} {
	    set focus [format "%5.0f" [expr ($m1_gain * -6 * $spher)/$defoc_fact]]
	    report "* Changing focus by $focus um\n"
          # catch {msg_cmd HEXSERV "focuserr $focus" 20000}
	    set tok [dns::resolve _hexapod._tcp.mmto.arizona.edu -type SRV]
	    set res [dns::result $tok]
	    set port [lindex [lindex [lindex $res 0] 11] 5]
	    set host [lindex [lindex [lindex $res 0] 11] 7]

	    catch {exec echo "offset_inc m1spherical z $focus" | nc -w 5 $host $port}
	    catch {exec echo "apply_offsets" | nc -w 5 $host $port}
	}

	report "* cell forces sent to crate.\n"
	
    } else {
	report "* Mirror bending not enabled.\n"
    }
    
}

proc m2focus { } {
    global focus_nm ref_focus_nm USEHEX zt defoc_fact m2_gain
    upvar #0 [lindex $zt 3] def

    # correct the focus
    if {$ref_focus_nm != ""} {
	set focus [format "%5.0f" [expr ($ref_focus_nm-$focus_nm)*$m2_gain/$defoc_fact]]
	report "* Changing focus by $focus um\n"
	if {$USEHEX} {
          # catch {msg_cmd HEXSERV "focuserr $focus" 20000}
	    set tok [dns::resolve _hexapod._tcp.mmto.arizona.edu -type SRV]
	    set res [dns::result $tok]
	    set port [lindex [lindex [lindex $res 0] 11] 5]
	    set host [lindex [lindex [lindex $res 0] 11] 7]

	    catch {exec echo "offset_inc wfs z $focus" | nc -w 5 $host $port}
	    catch {exec echo "apply_offsets" | nc -w 5 $host $port}
	}
	set focus_nm $ref_focus_nm ; # set offset to zero until next zernikes
	set def $ref_focus_nm
    }
}

proc m2correct { } {
    global thetax thetay tilt_x tilt_y zt USEHEX USEREPOINT cc_trans \
	zc_trans maxM2tilt m2_gain

    set translate_x 0; set translate_y 0; # null hexapod translation offsets

    set tok [dns::resolve _hexapod._tcp.mmto.arizona.edu -type SRV]
    set res [dns::result $tok]
    set port [lindex [lindex [lindex $res 0] 11] 5]
    set host [lindex [lindex [lindex $res 0] 11] 7]
	
    if {$USEHEX} {
	set tx [expr $m2_gain * $thetax]
	report "* Moving thetaX = $tx arcsec\n"
	catch {exec echo "offset_inc wfs tx $tx" | nc -w 5 $host $port}
	# repoint will now do hexapod translations instead of mount
	# translations.  cc_trans is the amount of um of trans per
	# arcsec of tilt.  the sense should be the same as with
	# telescope repointing.
	set translate_y [expr $tx * $cc_trans]
	report "* Moving transY = $translate_y um\n"

	catch {exec echo "offset_inc wfs y $translate_y" | nc -w 5 $host $port}
    }
    if {$USEHEX} {
	set ty [expr $m2_gain * $thetay]
	report "* Moving thetaY = $ty arcsec\n"
	catch {exec echo "offset_inc wfs ty $ty" | nc -w 5 $host $port}
	set translate_x [expr $ty * -$cc_trans]
	report "* Moving transX = $translate_x um\n"
	catch {exec echo "offset_inc wfs x $translate_x" | nc -w 5 $host $port}
	catch {exec echo "apply_offsets" | nc -w 5 $host $port}
    }

    # create links to zernike display entry boxes
    upvar #0 [lindex $zt 6] xcom
    upvar #0 [lindex $zt 7] ycom
    upvar #0 [lindex $zt 2] t_xax
    upvar #0 [lindex $zt 1] t_yax
    
    # set tilts to zero after correction is sent to M2 (just in case the
    # correction button is pressed again accidentally).
    set thetax 0 ; set thetay 0 ;

    # clear coma and tilts from zernike window to show corrections are applied
    set xcom 0 ; set ycom 0; 
    #set t_xax $ref_tilt_xax; set t_yax $ref_tilt_yax
    
    # correct the tilts
    #if {$ref_tilt_yax != "" && $ref_tilt_xax != ""} {

#  	#first do the Y tilt
#  	set tilt_y_zc [expr ($ref_tilt_yax - $tilt_y)*0.0002175]
#  	set tran_x_zc [expr $tilt_y_zc * -$zc_trans]
#  	if {$USEHEX} {
#  	    report "* Moving thetaY = $tilt_y_zc arcsec\n"
#  	    catch {msg_cmd HEXSERV "tiltyerr $tilt_y_zc" 20000}
#  	    report "* Moving transX = $tran_x_zc um\n"
#  	    catch {msg_cmd HEXSERV "transxerr $tran_x_zc" 20000}
#  	}

#  	#now the X tilt
#  	set tilt_x_zc [expr ($ref_tilt_xax - $tilt_x)*0.0002175]
#  	set tran_y_zc [expr $tilt_x_zc * $zc_trans]
#  	if {$USEHEX} {
#  	    report "* Moving thetaX = $tilt_x_zc arcsec\n"
#  	    catch {msg_cmd HEXSERV "tiltxerr $tilt_x_zc" 20000}
#  	    report "* Moving transY = $tran_y_zc um\n"
#  	    catch {msg_cmd HEXSERV "transyerr $tran_y_zc" 20000}
#  	}

#  	set tilt_y $ref_tilt_yax; # set offsets to zero until next zernikes
#  	set tilt_x $ref_tilt_xax

    #}	

}

proc setRefFoc { focus } {

    global ref_focus_nm 

    set ref_focus_nm $focus ; # set reference to currently measured focus

    report "* setting ref focus to $focus\n"

}

proc setRefSpher { spher } {

    global ref_spher_nm 

    set ref_spher_nm $spher ; # set reference to currently measured focus

    report "* setting ref spherical to $spher\n"

}

#-------------------------------------------------------------------
#modeAxialForces is responsible for passing the zernike polynomial file and
#a poly mask to bcv.c which then calculates the axial forces that
#compensate the observed wavefront errors.  This routine works only for pure
#Zernike modes and not raw phases or their residuals--do this later.

proc modeAxialForces { } {
    global mask zfile AVHOME G2 rmsLabels rms_calc act_forces actN \
	actmap xpmimg fbox m1 m2 m2foc m1_gain fmode
    createMask

    if {$fmode == "F9"} {
	set command "$AVHOME/bcv $zfile $mask $m1_gain"
    } else {
	set command "$AVHOME/bcv_f5 $zfile $mask $m1_gain"
    }
    puts "modeAxialForces command is: $command"

    set bcvfid [open |$command r]
    set modeForces [read $bcvfid]
    close $bcvfid
    report "* $modeForces\n"
	
    #make sure that "draw pupil" completely updates itself
    set rms_calc 0

    # refresh the actuator force XPM image
    image create pixmap act_map -file actforce.xpm
    $xpmimg itemconfigure actmap -image act_map

    #set forcefile zfile
    regsub {.zrn} $zfile {.forces} forcefile

    #write a file with the corrective force distribution
    set cfid [open $forcefile w]
    for {set i 0} {$i <104} {incr i} {
	puts -nonewline $cfid [lindex $actN $i]
	puts -nonewline $cfid \t
	puts $cfid [lindex $modeForces $i]
    }
    close $cfid

    #flush modeforces to the scrolling listbox for viewing
    $fbox delete 0 end
    for {set i 0} {$i < 104} {incr i} {
	set str [format "%5d %9.1f" [lindex $actN $i] [lindex $modeForces $i]]
	$fbox insert end $str 
    }	
    
    $m1 configure -bg green ; # OK to correct primary
    $m2 configure -bg green ; # OK to correct coma
    $m2foc configure -bg green ; # OK to correct focus
}
#-------------------------------------------------------------------

# shzrn used to call showzerns() directly, but now it calls an intermediate
# procedure to compensate for the automation of the work flow.
button $shzrn -text "Load File" -command {showzernsInt}
button $axfor -text "Axial Forces" -command {modeAxialForces}
button $pup_PSF -text "Pupil modes" -command {
    createMask
    draw_pupil $zfile $mask
} 

set addlog [button $ABER.addlog -text "Add to Log" -command {AddLogEntry}]

proc createMask { } {
    global ZPOLY mask 
    set mask ""
    # the [set z$i] just reads the contents of the variable--hard to do any
    # other way (i.e. you can't read z1 by saying puts $z$i).--I changed
    # this to upvar since it's now 1 level down in a procedure.
    #mask is a string mask for calculating phase from zernike terms.
    for {set i 1} {$i <= $ZPOLY} {incr i} {
	upvar #0 z$i ta
	set mask ${mask}$ta 
    }
    report "Mask is $mask.\n"
}
	
#---------------------------------------------------------------------
pack $AVC.name
pack $AVC.f1.dir $AVC.f1.dirlabel -side left
pack $AVC.f1
pack $AVC.f3.name $AVC.f3.fits $AVC.f3.ref $AVC.f3.ctr $AVC.f3.aver $AVC.f3.all \
    $AVC.f3.zrn $AVC.f3.reload -fill x

#pack $AVC.f4.name $AVC.f4.centroid $AVC.f4.average $AVC.f4.zernike $AVC.f4.system $AVC.f4.ref 
#pack $AVC.f4.centroid $AVC.f4.average $AVC.f4.zernike $AVC.f4.system $AVC.f4.ref $AVC.f4.tom
pack $AVC.f4.centroid $AVC.f4.average $AVC.f4.zernike $AVC.f4.system $AVC.f4.ref

pack $AVC.f2.files -fill x -side left
pack $AVC.f2.ttscroll -side right -fill y
pack $AVC.f3 $AVC.f2 $AVC.f4 -side left
pack $AVC

#pack .wfs.gen.md.grd .wfs.gen.md.phs -fill x
#pack .wfs.gen.ex .wfs.gen.sysname .wfs.gen.sys .wfs.gen.md -side left
pack .wfs.gen.ex .wfs.gen.sysname .wfs.gen.sys -side left
pack .wfs.gen -fill x

pack $txt.v_scroll -side right -fill y
pack $reptxt -side left
pack $txt

pack .wfs

pack $xpmimg
pack $xpmpsf.dsl $xpmpsf.ds $xpmpsf.fldl $xpmpsf.fld $xpmpsf.rngl \
    $xpmpsf.rng	-side left -ipadx 1m 
pack $xpmpsf

#pack the rms graph
pack $G2 $frclist -side right 
pack $wframe -side left 

pack $shzrn $pup_PSF $axfor -side left

for {set i 1} {$i <= $ZPOLY} {incr i} {
    grid configure $ztable.${i}c -column 0 -row $i -sticky snew
    grid configure $ztable.${i}l -column 1 -row $i
    grid configure $ztable.${i}e -column 2 -row $i
}
grid configure $ztable.tilt -column 3 -row 1
grid configure $ztable.focus -column 3 -row 3
grid configure $ztable.astig -column 3 -row 4
grid configure $ztable.coma -column 3 -row 6
grid configure $ztable.trefoil -column 3 -row 9
grid configure $ztable.ashtray -column 3 -row 11
#grid configure $ztable.4th -column 3 -row 13
#grid configure $ztable.hitre -column 3 -row 15

pack $ztable
pack $zactions

pack $logname.ofilel $logname.ofilee -side left
pack $logname

pack $logframe.comml $logframe.comme -side left
pack $logframe

pack $addlog

pack $m2 $m1 -fill x
pack $correctfrm -fill x

pack $cenbut $m2foc -fill x
pack $focfrm -fill x

msg_up WFSSERV

# The following added by tjt 3-31-2011 to automatically
# poll and scan for new files that may appear.

set first 0
colorButtons

# scan every 2 seconds
set update_interval 2000

proc ticker {} {
    global update_interval

    update_files
    after $update_interval ticker
}

after $update_interval ticker

# THE END
