
PACKAGES = 	ljack.tcl	\
		puntino.tcl	\
		pmac.tcl	\
		pmacserv.tcl	\
		viahm.tcl	\
		msg.tcl		\
		bob.tcl		\
		try.tcl		\
		maxim.tcl	\
		sbig.tcl	\
		pixelink.tcl	\
		camserv.tcl

COMMANDS =	pmac			\
		pmacpp			\
		pmacindent		\
		viahm			\
		mmove mhome		\
		tmove thome		\
		cmove chome ctags	\
		fmove fhome		\
		pmove phome pmovr plite	\
		abort

install:
	cp pkgIndex.tcl $(PACKAGES)	C:/Tcl/lib/mmti/.
	cp $(COMMANDS)			/home/wave/bin/.

package:
	echo "pkg_mkIndex -verbose . $(PACKAGES)" | tclsh 

xx : xx.c
	gcc -g xx.c -o xx.exe C:/Windows/system32/ljackuw.dll
