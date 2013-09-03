set ::milli 0

set Counter	$env(HOME)/.image
set DataDir	/data/ccd/john/wave
set MaxData	[expr 2880 * 3 + 1280 * 1024 * 2]

set wfs_dir   /data/ccd/wfs/wfs
set wfs_bin   1
set wfs_shm   2001

set wfs_filters {}
set wfs_bins    { 1 2 3 }
set wfs_cooler  1

set wfs_fx1   0
set wfs_fy1   0
set wfs_fnx 512
set wfs_fny 512

set wfs_bx1 [expr $wfs_fnx/2 - 50]
set wfs_by1 [expr $wfs_fny/2 - 50]
set wfs_bnx 100
set wfs_bny 100

set wfs_full  0
set wfs_expunits  sec


set sci_dir   /data/ccd/wfs/sci
set sci_bin   1
set sci_shm   2002

set sci_filters { U B V R I }
set sci_bins    { 1 2 3 4 8 }
set sci_cooler  1

set sci_fx1    0
set sci_fy1    0
set sci_fnx 1034
set sci_fny 1024

set sci_bx1 [expr $sci_fnx/2 - 100]
set sci_by1 [expr $sci_fny/2 - 100]
set sci_bnx  200
set sci_bny  200

set sci_full  0
set sci_expunits  sec


set pix_dir   /data/ccd/wfs/pix
set pix_bin   1
set pix_shm   2003

set pix_filters {}
set pix_bins    { 1 2 4 }
set pix_cooler  0

set pix_fx1    0
set pix_fy1    0
set pix_fnx 1280
set pix_fny 1024

set pix_bx1  550
set pix_by1  500
set pix_bnx  200
set pix_bny  200

set pix_full  0
set pix_expunits  msec

