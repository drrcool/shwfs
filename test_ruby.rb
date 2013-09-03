#!/usr/bin/ruby
#
#
#center = system("/mmt/shwfs/get_pupil_center /mmt/shwfs/datadir/auto_wfs_0008.fits F5 2> /dev/null")
center = %x{/mmt/shwfs/get_pupil_center /mmt/shwfs/datadir/auto_wfs_0008.fits F5 2> /dev/null}
#center = `/mmt/shwfs/get_pupil_center /mmt/shwfs/datadir/auto_wfs_0008.fits F5 2> /dev/null`
print center.to_s + "\n"
