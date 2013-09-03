
package provide puntino 1.0

namespace eval puntino {
    namespace export {[a-z]*}

    variable Errors {
	"no error"
	"unrecognized command"
	"illegal command"
	"illegal Parameter"
	"time out trying to reach home"
	"invalid parameters in internal memory"
    }


    proc init { port } {
	set file [open $port RDWR]
	fconfigure $file -blocking no 
	fconfigure $file -translation { crlf crlf } 
	fconfigure $file -mode 9600,n,8,1 

      catch {
	puntino::firm $file
	puntino::send $file SX,600
	puntino::comm $file SX?	4
      }

	return $file
    }

    proc send { file comm } {
	read  $file
	puts  $file $comm
	flush $file
    }
    proc recv { file time } {
	set reply {}
	variable timedout 0

	set timeout_after [after [expr $time*1000] ::puntino::timeout]

	while { ![string compare $reply {}] } {
	    if { $timedout } {
		after cancel $timeout_after
		error "puntino: timed out waiting for recv"
	    }

	    update
	    set reply [gets $file]
	}
	after cancel $timeout_after
	return $reply
    }
    proc comm { file comm time } {
	puntino::send $file $comm
	puntino::recv $file $time
    }

    proc timeout { } {
	set ::puntino::timedout 1
    }

    proc wait { file posi time } {
	    global pA
	    variable timedout 0

	set timeout_after [after [expr $time*1000] { puntino::timeout }]

	while { $pA != $posi } {
	    if { $timedout } {
		after cancel $timeout_after
		error "puntino: timed out waiting for move"
	    }

	    update
	    set pA [puntino::posi $file]
	}
	after cancel $timeout_after
    }
    proc firm { file } {
	puntino::comm $file ? 1
    }
    proc home { file } {
	puntino::firm $file
	puntino::send $file SX,600
	puntino::comm $file SX?	4
	puntino::send $file Hx
	after 10000

	if { [catch { puntino::stat $file }] } {
	puts Err
	    puntino::send $file D5,x
	    after 1000
	    puntino::send $file Hx
	    after 5000

	    puntino::stat $file
	}
    }
    proc posi { file } {
	set reply [split [puntino::comm $file W 4] ,]
	lindex $reply 0
    }
    proc move { file posi } {
	if { $posi > 625 } {
	    error "Cannot move puntino past 625"
 	}
	puntino::send $file X$posi
	puntino::wait $file $posi 15
    }
    proc movr { file posi } {
	puntino::send $file D$posi,x
	puntino::wait $file [expr $::pA + $posi] 15
    }
    proc stat { file } {
	variable Errors

	set reply 0x[split [puntino::comm $file U 4] ,]

	set stat [lindex $reply 0]
	set erro [lindex $reply 1]

	if { $stat & 0x80 } {
	    error "puntino: $reply [lindex $Errors $erro]"
	}
	return $stat
    }
    proc lite { file lite } {
	puntino::send $file L$lite
	after 100

	if { (!!([puntino::stat $file] & 0x10)) != $lite } {
	    error "lite not set to $onoff"
	}
    }
}

if { 0 } {
	proc spike {} {
		global pun
		set line [gets stdin]
		eval puntino::[lindex $line 0] $pun [lrange $line 1 end]
	}
	#fileevent stdin r spike

	set   pun [puntino::init COM1:]
	puntino::home $pun

	set   cur [puntino::stat $pun]
	puts $cur

	proc Update { } {
	    	global pun pA;  set pA [puntino::posi $pun]
		after 1000 Update
	}

	Update
	proc move { } {
		global pun

	    puts [set posi [puntino::posi $pun]]

	    if { $posi < 200 } {
		puntino::move $pun 600
	    } else {
		puntino::move $pun 60
	    }
	    puts [set posi [puntino::posi $pun]]

	    after 5000 move
	}

	move

	while { 1 } {
	    after 100
	    set   now [puntino::stat $pun]
	    if { [string compare $cur $now] } {
		puts "$cur -> $now"
		set   cur $now
	    }
	    update
	}
}
