CC=gcc
CFLAGS=-O2

all:	findstars maestrostars azel2radec

clean:
	rm -f *.o *~ findstars

deltat.o: astro.h P_.h deltat.c
	${CC} ${CFLAGS} -c deltat.c

homeio.o: astro.h P_.h circum.h homeio.c
	${CC} ${CFLAGS} -c homeio.c

precess.o: astro.h P_.h precess.c
	${CC} ${CFLAGS} -c precess.c

xe2.o: astro.h P_.h circum.h xe2.c
	${CC} ${CFLAGS} -c xe2.c

time.o: P_.h circum.h time.c
	${CC} ${CFLAGS} -c time.c

aa_hadec.o: astro.h P_.h aa_hadec.c
	${CC} ${CFLAGS} -c aa_hadec.c

misc.o: astro.h P_.h circum.h misc.c
	${CC} ${CFLAGS} -c misc.c

nutation.o: astro.h P_.h circum.h nutation.c
	${CC} ${CFLAGS} -c nutation.c

obliq.o: astro.h P_.h circum.h obliq.c
	${CC} ${CFLAGS} -c obliq.c

utc_gst.o: astro.h P_.h circum.h utc_gst.c
	${CC} ${CFLAGS} -c utc_gst.c

mjd.o: astro.h P_.h mjd.c
	${CC} ${CFLAGS} -c mjd.c

sphcart.o: astro.h P_.h sphcart.c
	${CC} ${CFLAGS} -c sphcart.c

ap_as.o: astro.h P_.h circum.h ap_as.c
	${CC} ${CFLAGS} -c ap_as.c

circum.o: astro.h P_.h circum.h circum.c
	${CC} ${CFLAGS} -c circum.c

aberration.o: astro.h P_.h aberration.c
	${CC} ${CFLAGS} -c aberration.c

eq_ecl.o: astro.h P_.h eq_ecl.c
	${CC} ${CFLAGS} -c eq_ecl.c

sun.o: astro.h P_.h sun.c
	${CC} ${CFLAGS} -c sun.c

refract.o: astro.h P_.h refract.c
	${CC} ${CFLAGS} -c refract.c

parallax.o: astro.h P_.h parallax.c
	${CC} ${CFLAGS} -c parallax.c

vsop87.o: astro.h P_.h vsop87.h vsop87.c
	${CC} ${CFLAGS} -c vsop87.c

vsop87_data.o: astro.h P_.h vsop87.h vsop87_data.c
	${CC} ${CFLAGS} -c vsop87_data.c

findstars: wfscat.c astro.h P_.h circum.h deltat.o homeio.o mjd.o precess.o \
	xe2.o time.o 
	${CC} ${CFLAGS} wfscat.c -lm deltat.o homeio.o precess.o xe2.o \
	time.o mjd.o -o findstars

maestrostars: maestro.c astro.h P_.h circum.h deltat.o homeio.o mjd.o precess.o \
	xe2.o time.o 
	${CC} ${CFLAGS} maestro.c -lm deltat.o homeio.o precess.o xe2.o \
	time.o mjd.o -o maestrostars

azel2radec: azel2radec.c astro.h P_.h circum.h utc_gst.o obliq.o nutation.o \
	misc.o aa_hadec.o time.o mjd.o sphcart.o deltat.o ap_as.o precess.o \
	circum.o aberration.o eq_ecl.o sun.o refract.o vsop87.o vsop87_data.o \
	parallax.o
	${CC} ${CFLAGS} azel2radec.c -lm utc_gst.o obliq.o nutation.o misc.o \
	aa_hadec.o time.o sphcart.o mjd.o deltat.o ap_as.o precess.o \
	circum.o aberration.o eq_ecl.o sun.o refract.o vsop87.o \
	vsop87_data.o parallax.o -o azel2radec
