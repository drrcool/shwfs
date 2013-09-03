
grid [label  .name -text [file rootname [file tail $argv0]]]
grid [button .exit -text Exit -command { exit }]

wm geometry . $geometry
