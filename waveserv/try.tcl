
package provide try 1.0

proc try { args } {
    if { [catch {
	uplevel "eval $args"
    } error] } {
	puts stderr $error
    }
}

