

proc ivar { a m name number } {
	puts "#define ${a}${name} i${m}${number}"
}
proc mvar { name number addr } {
	puts "#define ${name} ${number}"
	puts "${name}->$addr"
}
proc pvar { name number } {
	puts "#define ${name} ${number}"
}
proc ax_mvar { a m name number addr } {
	mvar  ${a}${name} m${m}${number} $addr
}
proc ax_pvar { a m name number } {
	pvar  ${a}${name} p${m}${number}
}
proc ax_iven { a m name number } {
	puts "#define ${a}${name} i[expr 900 + (($m-1) * 5 ) + ${number}]"
}
proc ax_mvdp { a m name number type } {
	if { ![string compare $type F] } {
	 ax_mvar $a $m $name $number F:\$D[expr $m+4]${number}
	}
	if { ![string compare $type X] || ![string compare $type Y] } {
	 ax_mvar $a $m $name $number "$type:\$D[expr $m+4]${number},0,16"
	}
}
proc ax_mvsv { a m name number type base stride { offset {} } } {
	if { ![string compare $type D] } {
	 ax_mvar $a $m $name $number "D:\$[format %04X [expr $base + ($m-1)*$stride]]"
	}
	if { ![string compare $type x] || ![string compare $type y] } {
	 ax_mvar $a $m $name $number		\
		"$type:\$[format %04X [expr $base + ($m-1)*$stride]],$offset,1"
	}
	if { ![string compare $type X] || ![string compare $type Y] } {
	 ax_mvar $a $m $name $number "$type:\$[format %04X [expr $base + ($m-1)*$stride]],0,24"
	}
}
proc ax_mvgt { a m name number type offset } {
	set addr [lindex { 0xC000 0xC004 0xC008 0xC00C } [expr $m-1]]

	if { ![string compare $type x] || ![string compare $type y] } {
	 ax_mvar $a $m $name $number "$type:\$[format %04X $addr],$offset,1"
	}
	if { ![string compare $type X] || ![string compare $type Y] } {
	 ax_mvar $a $m $name $number "$type:\$[format %04X [expr $addr + $offset]],0,24,S"
	}
}

