
set geometry +160+138
source gui.tcl

package require  msg

package require  camserv
package require  sbig
#package require  maxim
#package require  pixelink


set null ""
set DataDir	[pwd]

set allow {
 	192.168.1.2 portal hacksaw
	192.168.1.31 128.196.100.19	hoseclamp hoseclamp.mmto.arizona.edu
	128.196.100.28	  alewife.mmto.arizona.edu
	128.196.100.31	  hacksaw.mmto.arizona.edu
	192.168.1.19 192.168.1.1 128.196.100.19 localhost
}

set allow "*"

camserv::server WFS 3001 sbig 	  0 $allow

#camserv::server SCI 3002 maxim    0 $allow 
#camserv::server PIX 3003 pixelink  0 $allow

vwait forever

