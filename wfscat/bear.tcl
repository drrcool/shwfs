#!/data/mmti/bin/tclsh

load /data/mmti/tcl/sla.so

set r1 [lindex $argv 0]
set d1 [lindex $argv 1]
set r2 [lindex $argv 2]
set d2 [lindex $argv 3]

set b [bear $r1 $d1 $r2 $d2]

puts $b
