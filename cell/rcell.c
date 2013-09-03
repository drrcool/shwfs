/* rcell.c
 * (previously xcell.c)
 *
 * This program talks to the appropriate sockets to get info
 * from the VxWorks Mirror cell control software.
 *
 * This is a unix program.
 *
 * T. Trebisky  10-9-92, 12-10-96
 * $Id: rcell.c,v 1.4 1999/05/28 19:30:14 tom Exp $
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <fcntl.h>
#include <sys/time.h>
#include <signal.h>
#include <time.h>

#include "cell_config.h"
#include "cell_net.h"

#define MAXLINE		256

#ifdef notdef
char hname[MAXLINE];
char *dname = "vw7";
#endif

char *mname;
char *cname = "mmtcell";

int option = 'i';	/* INFO */

struct status cell_status;

float ntohf(float);
float htonf(float);

void
quit(int sig)
{
	exit(0);
}

void
sigconnect(int sig, void (*func)())
{
	struct sigaction sa;

	sa.sa_handler   = func;
	sa.sa_flags     = 0;
	sigemptyset ( &sa.sa_mask );
	if ( sigaction ( sig, &sa, NULL ) < 0 )
	    error("Trouble installing signal");
}

int global_argc;
char **global_argv;

main(argc,argv)
char **argv;
{
	register char *p;

	sigconnect(SIGINT,quit);

#ifdef notdef
	mname = dname;
	if ( gethostname(hname,MAXLINE) )
	    error("Cannot get host name");

	if ( strcmp(hname,"afone") == 0 )
	    mname = cname;
	if ( strcmp(hname,"dorado") == 0 )
	    mname = cname;
	if ( strcmp(hname,"castor") == 0 )
	    mname = cname;
#endif

	mname = cname;

	++argv;
	--argc;

	while ( argc ) {
	    if ( argv[0][0] != '-' )
		break;
	    --argc;
	    p = *argv++ + 1;
	    if ( *p == 'M' ) {
		if ( argc-- < 1 )
		    error ("no machine name");
		mname = *argv++;
	    } else {
		option = *p;
		break;
	    }
	}

#ifdef notdef
	printf("host machine: %s\n",hname);
	printf("will contact machine: %s\n",mname);
#endif

#ifdef notdef
	check_cell();
	printf("will run option: %c\n",option);
#endif

	global_argc = argc;
	global_argv = argv;

	if ( option == 'i' ) {		/* info (default) */
	    do_info(1);
	    do_time();
	}
	else if ( option == 'R' )	/* [park mirror] and reboot */
	    do_reboot();
	else if ( option == 'm' )
	    do_mon1(argc,argv);
	else if ( option == 'S' )
	    do_snap();
	else if ( option == 'F' )	/* Force data (big block) */
	    do_mon2(argc,argv);
	else if ( option == 'a' )
	    do_air(argc,argv);
	else if ( option == 'p' )	/* hardpoint position and force */
	    do_pos();
	else if ( option == 't' )	/* get boot and current time */
	    do_time();
	else if ( option == 'f' )	/* fast raw ADC data in volts */
	    do_fadc(argc,argv);
	else if ( option == 'T' )	/* trace (fast single channel) */
	    do_trace(0);
	else if ( option == 'B' )	/* trace (fast single channel) */
	    do_trace(1);
	else if ( option == 'z' )	/* Z influence functions */
	    do_zinf();
	else if ( option == 'Z' )	/* Z influence functions */
	    get_zinf();
	else if ( option == 'c' )	/* clear inf data */
	    do_clinf();
	else if ( option == 'n' )	/* "nuke" - clear *all* inf data */
	    do_ninf();

#ifdef notyet	/* ----------------------------------- */
#define	OPT_INF		'v'	/* *old (BAD)* Z influence functions */
	else if ( option == OPT_INF )
	    do_inf();
#define	OPT_YINF	'y'	/* Y influence functions */
	else if ( option == OPT_YINF )
	    do_yinf();
#define	OPT_STATS	'sxxx'
	else if ( option == OPT_STATS )
	    do_stats();
#define	OPT_RAMP	'r'
	else if ( option == OPT_RAMP )
	    do_ramp();
#define	OPT_RAISE	'u'	/* "up" raise the mirror */
	else if ( option == OPT_RAISE )
	    do_cmd(option);
#define	OPT_LOWER	'd'	/* "down" park the mirror */
	else if ( option == OPT_LOWER )
	    do_cmd(option);
#define	OPT_PANIC	'P'	/* PANIC stop */
	else if ( option == OPT_PANIC )
	    do_cmd(option);
#define	OPT_LVDT	'l'	/* set up lvdt values */
	else if ( option == OPT_LVDT )
	    do_lvdt();
#endif	/* ----------------------------------- */
	else
	    printf("unknown option\n");

	exit(0);
}

do_info(once)
{
	do_status();
}

do_status()
{
	get_status(&cell_status);

	switch ( cell_status.cstatus ) {
	    case BOOT:
		printf("Status: Booting\n");
		break;
	    case INIT:
		printf("Status: Initializing\n");
		break;
	    case DIAG:
		printf("Status: Running diagnostics\n");
		break;
	    case RUNNING:
		printf("Status: Running\n");
		break;
	    case PANIC:
		printf("Status: PANIC\n");
		/*
		printf("Status: PANIC: %s\n",cell_status.c_panic);
		*/
		break;
	    default:
		printf("Status: unknown %d\n",cell_status.cstatus);
		break;
	}

	switch ( cell_status.mstatus ) {
	    case DOWN:
		printf("Mirror is down.\n");
		break;
	    case RAISING:
		printf("Mirror is being raised.\n");
		break;
	    case LOWERING:
		printf("Mirror is being lowered.\n");
		break;
	    case PAUSE:
		printf("Mirror is paused.\n");
		break;
	    case UP:
		printf("Mirror is up (FE).\n");
		break;
	    case RUN:
		printf("Mirror is up.\n");
		break;
	    case TEST:
		printf("Mirror is in TEST mode.\n");
		break;
	    case HOLD:
		printf("Mirror is in HOLD mode.\n");
		break;
	    case BLEED:
		printf("Mirror is in BLEED mode.\n");
		break;
	    default:
		printf("Mirror status: unknown %d\n",cell_status.mstatus);
		break;
	}

	/*
	if ( cell_status.c_errors )
	    printf("%d unread errors\n",cell_status.c_errors);
	*/
}


get_status(buf)
struct status *buf;
{
	int sn;
	int nio;

	if ( (sn=net_setup(CELL_PORT,GET_STATUS,0)) < 0 ) {
	    fprintf(stderr,"Cannot contact: %s\n",mname);
	    exit(1);
	}

	nio = netread( sn,(char *)buf, sizeof(struct status) );
	close(sn);

#if BYTE_ORDER == LITTLE_ENDIAN
	buf->cstatus = ntohl(buf->cstatus);
	buf->mstatus = ntohl(buf->mstatus);
#endif

	return ( nio );
}

do_reboot()
{
	int sn;

	if ( (sn=net_setup(REBOOT_PORT,RB_REBOOT,0)) < 0 ) {
	    fprintf(stderr,"Cannot reboot: %s\n",mname);
	    exit(1);
	}

	/* no data */

	close(sn);
	fprintf(stderr,"Reboot requested.\n");
}

char *
wonk_time(time_t atime)
{
	static char buf[MAXLINE];
	time_t time;
	struct	tm *tp;

	/*
	time_t	t;
	time (&t);
	gmtime_r (&t, &tb);
	localtime_r (&t, &tb);
	tp = &tb;
	*/

#if BYTE_ORDER == LITTLE_ENDIAN
	time = ntohl(atime);
#else
	time = atime;
#endif

	tp = localtime (&time);
	/*
	(void) strftime (buf, MAXLINE, "%H:%M:%S", tp);
	*/
	(void) strftime (buf, MAXLINE, "%m/%d/%y %H:%M:%S", tp);
	return buf;
}


do_time()
{
	int sn;
	time_t btime = 0;
	time_t ctime = 0;

	if ( (sn=net_setup(CELL_PORT,GET_TIME,0)) < 0 )
	    error("net setup fails");

	(void) netread( sn, (char *) &btime, sizeof(time_t));
	(void) netread( sn, (char *) &ctime, sizeof(time_t));
	close (sn);

	printf("boot: %s\n",wonk_time(btime));
	printf("cur:  %s\n",wonk_time(ctime));
}

/* implement the -f option
 * first argument is channel,
 * second is how many seconds of data (at 1000 Hz).
 */
do_fadc(argc,argv)
char **argv;
{
	int chan;
	long secs;
	long count;
	float *buf, *bp;
	int sn, nio, n;
	register int record;

	/* User argument is how much data
	 */
	if ( argc < 1 ) {
	    chan = 0;
	    secs = 1;
	} else if ( argc < 2 ) {
	    chan = atol(*argv);
	    secs = 1;
	} else {
	    chan = atol(*argv++);
	    secs = atol(*argv);
	}

	if ( secs < 1 )
	    return;

	fprintf(stderr,"Stand by!  getting your fast adc data.\n");

	if ( (sn=net_setup(CELL_PORT,DO_FADC,chan)) < 0 )
	    error("net setup fails");

	secs = htonl(secs);
	netwrite ( sn, (char *) &secs, sizeof(long) );

	/* long wait while data is gathered ..... */

	(void) netread( sn, (char *) &count, sizeof(long));
	count = ntohl(count);

	if ( count < 0 )
	    error("Cannot get that much data!\n");
	if ( count == 0 )
	    error("No data.\n");

	nio = count*sizeof(float);
	bp = buf = (float *) malloc (nio);
	n = netread( sn,(char *)buf,nio);
	if ( n != nio ) {
	    close(sn);
	    fprintf(stderr,"Expected %d, got %d bytes\n",nio,n);
	    error("bad data from network");
	}

	for ( record = 0; record < count; ++record ) {
	    /*
	    printf("%7d",record+1);
	    */
	    printval(*bp++);
	    printf("\n");
	}

	close(sn);
	free ( (char *) buf );
}

printval(aval)
float aval;
{
	float val = ntohf(aval);

	if ( val < 1.0 )
	    printf("%10.6f",val);
	else
	    printf("%10.5f",val);
}

do_trace(bogus)
{
	int sn, nio;
	int item;
	float *buf;
	long count = 0;
	long num;

	item = 0;
	num = 1000;

	if ( global_argc > 0 )
	    item = atol(*global_argv++);
	if ( global_argc > 1 )
	    num = atol(*global_argv);
	if ( bogus )
	    item = -1;

	buf = (float *) malloc (num * sizeof(float));

	if ( (sn=net_setup(CELL_PORT,GET_RAPID,item)) < 0 )
	    error("net setup fails");

	num = htonl(num);
	netwrite ( sn, (char *)&num, sizeof(long) );

	netread( sn,(char *)&count,sizeof(long) );
	count = ntohl(count);
	if ( count <= 0 )
	    error("Sorry");

	nio = netread( sn,(char *)buf,count*sizeof(float) );
	if ( nio != count*sizeof(float) )
	    error("Bogus network read");

	while ( count-- )
	    printf("%12.4f\n",*buf++);

	close(sn);
	free ( (char *) buf );
}

/* implement the -m command.
 * Get the current force set and show it to us.
 */
do_mon1(argc,argv)
char **argv;
{
	int sn, nio, avg;
	struct net_act *buf;
	long count = 0;
	long clock = 0;

	if ( argc < 1 )
	    avg = 1;
	else
	    avg = atol(*argv);

	if ( (sn=net_setup(CELL_PORT,SET_MON_AVG,avg)) < 0 )
	    error("net setup fails");
	close(sn);

	buf = (struct net_act *) malloc (sizeof(struct net_act));

	if ( (sn=net_setup(CELL_PORT,GET_MON,0)) < 0 )
	    error("net setup fails");

	/* always get the current data.
	 * We could set clock to the clock value returned
	 * in the last set, and get a sequence.
	 */
	clock = htonl(clock);
	netwrite ( sn, (char *)&clock, sizeof(long) );
	netread( sn,(char *)&count,sizeof(long) );
	count = ntohl(count);

	/* always returns 1, unless malloc fails */

	while ( count-- ) {
	    nio = netread( sn,(char *)buf,sizeof(struct net_act) );
	    if ( nio == sizeof(struct net_act) )
		print_mon1(buf->nf);
	    else {
		fprintf(stderr,"Bogus network read\n");
		break;
	    }
	}

	close(sn);

	free ( (char *) buf );
}

/* implement the -s command.
 * Get the snapshot force set and show it to us.
 */
do_snap()
{
	int sn, nio;
	struct net_act *buf;
	long count = 0;

	buf = (struct net_act *) malloc (sizeof(struct net_act));

	if ( (sn=net_setup(CELL_PORT,GET_SNAP,0)) < 0 )
	    error("net setup fails");

	netread( sn,(char *)&count,sizeof(long) );
	count = ntohl(count);

	/* always returns 1, unless malloc fails */

	while ( count-- ) {
	    nio = netread( sn,(char *)buf,sizeof(struct net_act) );
	    if ( nio == sizeof(struct net_act) )
		print_mon1(buf->nf);
	    else {
		fprintf(stderr,"Bogus network read\n");
		break;
	    }
	}

	close(sn);

	free ( (char *) buf );
}

static char *color[] = {"red", "orange", "yellow", "blue" };

/* display a force set.
 * one line per actuator.
 * Used by -m and -s
 */
print_mon1(ip)
struct net_force *ip;
{
	register struct net_force *np;

	for ( np=ip; np<&ip[N_ACTU]; ++np ) {
	    printf("act %4d",ntohs(np->loc));
	    printf(" %6s",color[np->color]);
	    if ( ntohs(np->type) == ACT_SINGLE )
		printf("%10.2f %10.2f\n",ntohf(np->force1),ntohf(np->mon1));
	    else
		printf("%10.2f %10.2f %10.2f %10.2f\n",
		ntohf(np->force1),ntohf(np->mon1),
		ntohf(np->force2),ntohf(np->mon2));
	}
}

/* Implement the -F force monitor option.
 * requested by Steve West 3/24/98 to collect a lot of force
 * monitor data for noise analysis purposes.
 * one argument is the number of readings we want.
 * identical to -a except for format of the output.
 */
do_mon2(argc,argv)
char **argv;
{
	int sn, nio, num;
	struct net_act *buf;
	long rval;
	register i;
	long clock = 0;

	if ( argc < 1 )
	    num = 1;
	else
	    num = atol(*argv);

	buf = (struct net_act *) malloc (sizeof(struct net_act));

	for ( i=0; i<num; ++i ) {
	    if ( (sn=net_setup(CELL_PORT,GET_MON,0)) < 0 )
		error("net setup fails");

	    clock = htonl(clock);
	    netwrite ( sn, (char *)&clock, sizeof(long) );
	    netread( sn,(char *)&rval,sizeof(long) );
	    rval = ntohl(rval);
	    if ( rval < 1 )
		error("Cell, out of memory");

	    nio = netread( sn,(char *)buf,sizeof(struct net_act) );
	    if ( nio == sizeof(struct net_act) ) {
		/* Send the clock back for the next call.
		 */
		clock = buf->clock;
		print_mon2 ( ntohl(buf->clock), buf->nf );
	    } else {
		fprintf(stderr,"Bogus network read\n");
		break;
	    }
	}

	close(sn);

	free ( (char *) buf );
}

/* Print a block of force data, one actuator per line, but
 * with minimal "extra" information.
 * In particular, no force commands, only monitor data.
 * This produces a big matrix of nothing but force data,
 * with really long lines.  One line per "tick".
 */
print_mon2(clock,ip)
long clock;
struct net_force *ip;
{
	register struct net_force *np;

	printf("%8ld",clock);
	for ( np=ip; np<&ip[N_ACTU]; ++np ) {
	    if ( ntohs(np->type) == ACT_SINGLE )
		printf(" %12.3f",ntohf(np->mon1));
	    else
		printf(" %12.3f %12.3f", ntohf(np->mon1), ntohf(np->mon2));
	}
	printf("\n");
}

/* implement the -a option
 * one argument is the number of readings we want.
 */
do_air(argc,argv)
char **argv;
{
	int sn, nio, num;
	struct net_act *buf;
	long rval;
	register i;
	float psi[N_COLORS];
	long clock = 0;

	/* User argument is how much data
	 */
	if ( argc < 1 )
	    num = 1;
	else
	    num = atol(*argv);

	buf = (struct net_act *) malloc (sizeof(struct net_act));

	for ( i=0; i<num; ++i ) {
	    if ( (sn=net_setup(CELL_PORT,GET_MON,0)) < 0 )
		error("net setup fails");

	    clock = htonl(clock);
	    netwrite ( sn, (char *)&clock, sizeof(long) );
	    netread( sn,(char *)&rval,sizeof(long) );
	    rval = ntohl(rval);
	    if ( rval < 1 )
		error("Cell, out of memory");

	    nio = netread( sn,(char *)buf,sizeof(struct net_act) );
	    if ( nio != sizeof(struct net_act) ) {
		fprintf(stderr,"Bogus network read\n");
		break;
	    }
	    clock = buf->clock;	/* for the next call */
	    close(sn);

	    if ( (sn=net_setup(CELL_PORT,GET_PSI,0)) < 0 )
		error("net setup fails");
	    nio = netread( sn,(char *)psi,N_COLORS*sizeof(float) );
	    if ( nio != N_COLORS*sizeof(float) ) {
		fprintf(stderr,"Bogus network read\n");
		break;
	    }
	    close(sn);

	    print_air(ntohl(buf->clock),psi);
	    print_mon1(buf->nf);
	}

	free ( (char *) buf );
}

print_air(clock,psi)
long clock;
float psi[];
{
	register i;

	printf("clock %d\n",clock);

	printf("psi");
	for ( i=0; i<N_COLORS; ++i )
	    printf(" %.2f",ntohf(psi[i]));
	printf("\n");
}

/* Get and display hardpoint information:
 * position in mm referenced to nominal operating position.
 *	(negative values when mirror is down)
 * forces are platform (x,y,z and moments) actually seen
 *	on the hardpoints (zero when loops are closed).
 */
do_pos()
{
	showf(GET_HPLV,   N_HPA,"lvdt (rel)");
	showf(GET_HPLVABS,N_HPA,"lvdt (abs)");
	showf(GET_MAGIC,  N_HPA,"lvdt (magic)");
	showf(GET_HPLC,N_HPA,"lc");
	showf(GET_POS,N_HPV,"pos");
	showf(GET_FORCE,N_HPV,"forces");
}

showf(int netcmd, int nf, char *msg)
{
	float *buf;
	int sn, nio, i;
	float val;

	buf = (float *) malloc ( nf*sizeof(float) );

	if ( (sn=net_setup(CELL_PORT,netcmd,0)) < 0 )
	    error("net setup fails");

	nio = netread( sn,(char *)buf,nf*sizeof(float) );
	close(sn);

	printf("%8s=",msg);
	for ( i=0; i<nf; ++i ) {
	    val = ntohf(buf[i]);
	    if ( val < -100.0 || val > 100.0 )
		printf("%10.3f",ntohf(buf[i]));
	    else
		printf("%10.4f",ntohf(buf[i]));
	}
	printf("\n");

	free ( (char *) buf );
}

/* This sends the Z force updates one by one in a loop.
 * This is not really a good idea - better to send a whole batch.
 * do_zinf() is the prefered way.
 */
do_inf()
{
	char line[MAXLINE];
	int actnum, index;
	float value;

	while ( fgets(line,MAXLINE,stdin) != NULL ) {
	    if ( *line == '#' )
		continue;
	    if ( sscanf(line,"%d %f",&actnum,&value) != 2 ) {
		printf("Bad input line (ignored): %s\n",line);
		continue;
	    }
	    if ( (index=alookup(actnum)) < 0 ) {
		printf("Unknown actuator (ignored): %s\n",line);
		continue;
	    }
	    value *= PPNEWT;
	    if ( put_inf(index,value) <= 0)
		printf("Trouble adjusting force for %d\n",index);

	}
}

put_inf (actuator, force)
int actuator;
float force;
{
	int sn;
	short status = 0;

	if ( (sn=net_setup(CELL_PORT,PUT_AADJ,actuator)) < 0 )
	    error("put_inf, net setup fails");

	force = htonf(force);
	netwrite ( sn, (char *)&force, sizeof(float) );

	(void) netread( sn,(char *)&status,sizeof(short) );

	close(sn);

	return ntohs(status);
}

do_zinf()
{
	char line[MAXLINE];
	int actnum, index;
	float value;
	float forces[N_ACTU];
	int trouble = 0;

	for ( actnum=0; actnum<N_ACTU; ++actnum )
	    forces[actnum] = 0.0;

	while ( fgets(line,MAXLINE,stdin) != NULL ) {
	    if ( *line == '#' )
		continue;
	    if ( sscanf(line,"%d %f",&actnum,&value) != 2 ) {
		/*
		printf("Bad input line (ignored): %s\n",line);
		*/
		printf("Bad input line: %s\n",line);
		++trouble;
		continue;
	    }
	    if ( (index=alookup(actnum)) < 0 ) {
		printf("Unknown actuator: %s\n",line);
		++trouble;
		continue;
	    }
	    forces[index] = value * PPNEWT;
	}

	if ( trouble ) {
	    printf("Sorry!\n");
	    return;
	}

	printf("downloading force set, wait ...");
	fflush(stdout);

	/* status is:
	 *    1 if OK
	 *    0 if trouble.
	 */
	if ( put_zinf(forces) <= 0 )
	    printf("Trouble !!\n");
	else
	    printf("Done\n");
}

#ifdef notyet
do_yinf()
{
	char line[MAXLINE];
	int actnum, index;
	float value;
	float forces[N_ACTU];

	for ( actnum=0; actnum<N_ACTU; ++actnum )
	    forces[actnum] = 0.0;

	while ( fgets(line,MAXLINE,stdin) != NULL ) {
	    if ( *line == '#' )
		continue;
	    if ( sscanf(line,"%d %f",&actnum,&value) != 2 ) {
		printf("Bad input line (ignored): %s\n",line);
		continue;
	    }
	    if ( (index=alookup(actnum)) < 0 ) {
		printf("Unknown actuator (ignored): %s\n",line);
		continue;
	    }
	    forces[index] = value * PPNEWT;
	}
	put_yinf(forces);
}
#endif

struct identry {
	int	actid;
	int	actindex;
};

static struct identry idtable[N_ACTU];
static idtable_ready = 0;

alookup(anum)
int anum;
{
	int index;

	if ( ! idtable_ready ) {
	    for ( index=0; index<N_ACTU; ++index ) {
		idtable[index].actindex = index;
		idtable[index].actid = getanum(index);
		if ( idtable[index].actid < 0 )
		    error("Cannot get actuator translation");
	    }
	    idtable_ready = 1;
	    /*
	    printf("Table initialized\n");
	    */
	}

	for ( index=0; index<N_ACTU; ++index )
	    if ( anum == idtable[index].actid )
		return ( idtable[index].actindex );

	/* missed ! */
	return ( -1 );
}

getanum(index)
{
	int sn, nio;
	short actloc;

	if ( (sn=net_setup(CELL_PORT,GET_ACTLOC,index)) < 0 )
	    return -1;

	nio = netread( sn,(char *)&actloc,sizeof(short) );
	if ( nio != sizeof(short) )
	    return -1;
	close(sn);

	return ntohs(actloc);
}

put_zinf(forces)
float forces[];
{
	int sn, i;
	short status = 0;

	if ( (sn=net_setup(CELL_PORT,PUT_ZADJ,0)) < 0 )
	    error("net setup fails");

	for ( i=0; i<N_ACTU; i++ )
	    forces[i] = htonf(forces[i]);
	netwrite ( sn,(char *)forces,N_ACTU*sizeof(float) );

	(void) netread( sn,(char *)&status,sizeof(short) );

	close(sn);

	return ntohs(status);
}

get_zinf()
{
	float forces[N_ACTU];
	int sn, i;

	if ( (sn=net_setup(CELL_PORT,GET_ZADJ,0)) < 0 )
	    error("net setup fails");
	(void) netread ( sn,(char *)forces,N_ACTU*sizeof(float) );
	close(sn);

	for ( i=0; i<N_ACTU; i++ ) {
	    forces[i] = ntohf(forces[i]) / PPNEWT;
	    printf ("%d %10.2f\n", i < N_ACTU/2 ? i+1 : i+49, forces[i]);
	}
}

#ifdef notyet
put_yinf(forces)
float forces[];
{
	int sn, i;

	if ( (sn=net_setup(CELL_PORT,PUT_YADJ,0)) < 0 )
	    error("net setup fails");

	for ( i=0; i<N_ACTU; i++ )
	    forces[i] = htonf(forces[i]);
	netwrite ( sn,(char *)forces,N_ACTU*sizeof(float) );

	close(sn);
}
#endif

do_clinf()
{
	int sn, nio;
	short status;

	printf("clearing force set, wait ...");
	fflush(stdout);

	if ( (sn=net_setup(CELL_PORT,CLR_ADJ,0)) < 0 )
	    error("net setup fails");

	/* New - get a status return value */
	nio = netread( sn,(char *)&status,sizeof(short) );

	close(sn);

	status = ntohs(status);
	if ( status <= 0 )
	    printf("Trouble !!\n");
	else
	    printf("Done\n");
}

do_ninf()
{
	int sn, nio;
	short status;

	if ( (sn=net_setup(CELL_PORT,ZAP_ADJ,0)) < 0 )
	    error("net setup fails");

	/* New - get a status return value */
	nio = netread( sn,(char *)&status,sizeof(short) );


	close(sn);

	status = ntohs(status);
	if ( status <= 0 )
	    printf("Trouble !!\n");
	else
	    printf("Done\n");
}

#ifdef AFWL

/* AFWL */
do_stats()
{
#ifdef notdef
	int sn;
	struct statistics sbuf;
	int last_clock = -1;
	int nio;

	for ( ;; ) {
	    if ( (sn=net_setup(DEBUG_PORT,GET_STATISTICS,0)) < 0 )
		error("net setup fails");

	    nio = netread( sn,(char *)&sbuf,sizeof(sbuf) );
	    if ( nio <= 0 )
		printf("Oops (%d)!\n",nio);
	    else if ( sbuf.clock != last_clock ) {
		last_clock = sbuf.clock;
		printf("clock: %d\n",sbuf.clock);
		printf(" inner: %d\n",sbuf.iloop_count);
		printf(" outer: %d\n",sbuf.oloop_count);
		printf(" temp:  %d\n",sbuf.temp_count);
		printf(" snoop: %d\n",sbuf.snoop_count);
		printf(" idle:  %d\n",sbuf.idle_count);
		if ( sbuf.iloop_overrun )
		    printf(" inner overrun:  %d\n",sbuf.iloop_overrun);
		if ( sbuf.oloop_overrun )
		    printf(" outer overrun:  %d\n",sbuf.oloop_overrun);
	    }
	    close(sn);
	    sleep(3);	/* don't bash network link too hard */
	}
#endif
}

#define NTRYS 10

/* AFWL */
/* This should be called before anything else is attempted
 * to find out if the cell is in a mood to do anything else.
 */
check_cell()
{
	int first = 1;
	register i;

	/* allow several trys to establish contact,
	 * in case the system is booting.
	 */
	for ( i=0; i<NTRYS; ++i ) {
	    sleep(1);
	    cell_status.c_status = 0;
	    if ( get_status(&cell_status) > 0 )
		break;
	    if ( first ) {
		printf("Waiting for target system\n");
		first = 0;
	    }
	}

	if ( cell_status.c_status == 0 )
	    error("Target system does not respond");

	switch ( cell_status.c_status ) {
	    case SYS_INIT:
		printf("Cell is initializing\n");
		exit(0);
	    case SYS_PANIC:
		printf("Cell software has paniced\n");
		printf("Panic string: %s\n",cell_status.c_panic);
		exit(0);
	    case SYS_DIAG:
		printf("Cell is running diagnostics\n");
		exit(0);
	    case SYS_HALT:
		printf("Cell has HALTED!\n");
		exit(0);
	    case SYS_RUN:
		printf("Cell is Running fine\n");
		break;
		/* OK !! */
	    default:
		printf("Unknown status: %d\n",cell_status.c_status);
		exit(0);
	}
}

/* AFWL */
do_ramp()
{
#ifdef notdef
	int sn;
	struct ramp_stat rsbuf;
	int nio;
	int num;
	int ofd;

	if ( (sn=net_setup(DEBUG_PORT,GET_RSTAT,0)) < 0 )
	    error("net setup fails");

	ofd = open("ramp.dat",O_CREAT|O_WRONLY,0644);
	if ( ofd < 0 )
	    error("ramp file, open fails");
	num = 0;
	for ( ;; ) {
	    nio = netread( sn,(char *)&rsbuf,sizeof(rsbuf));
	    if ( nio != sizeof(rsbuf) )
		break;
	    ++num;
	    if ( num == 1 || num%100 == 0 )
		printf("Packet %d received\n",num);
	    write ( ofd, rsbuf, sizeof(rsbuf) );
	}
	close(ofd);
	close(sn);
	printf("last nio = %d\n",nio);
	if ( nio < 0 )
	    printf("errno = %d\n",errno);
	printf("All %d packets received\n",num);
#endif
}

/* AFWL */
do_cmd(option)
{
	int sn;
	int type;

	if ( option == OPT_RAISE )
	    type = CMD_RAISE;
	else if ( option == OPT_LOWER )
	    type = CMD_PARK;
	else if ( option == OPT_PANIC )
	    type = CMD_PANIC;
	else
	    return;

	if ( (sn=net_setup(CELL_PORT,type,0)) < 0 )
	    error("net setup fails");

	/* no data, just a command */

	close(sn);
}

/* AFWL */
do_lvdt()
{
	char line[MAXLINE];
	float values[N_LVDT];
	float value;
	register nlvdt;

	nlvdt = 0;
	while ( fgets(line,MAXLINE,stdin) != NULL ) {
	    if ( *line == '#' )
		continue;
	    if ( sscanf(line,"%f",&value) != 1 ) {
		printf("Bad lvdt value: %s\n",line);
		return;
	    }
	    if ( nlvdt >= N_LVDT ) {
		printf("Too many lvdt values\n");
		return;
	    }
	    values[nlvdt++] = value;
	}
	if ( nlvdt != N_LVDT )
	    printf("Wrong number of lvdt values\n");

	printf("Setting lvdt values\n");
	put_lvdt(values);
}

/* AFWL */
put_lvdt(values)
float values[];
{
	int sn, i;

	if ( (sn=net_setup(CELL_PORT,SET_LVPOS,0)) < 0 )
	    error("net setup fails");

	for ( i=0; i<N_LVDT; i++ )
	    forces[i] = htonf(forces[i]);
	netwrite ( sn,(char *)values,N_LVDT*sizeof(float) );

	close(sn);
}

/* AFWL */
float tt[NETC];

/* AFWL */
do_temp()
{
	int sn;

	if ( (sn=net_setup(DEBUG_PORT,GET_RAWTEMP,0)) < 0 )
	    error("net setup fails");

	netread( sn,(char *)tt,NETC*sizeof(float));
	close(sn);

	/* Output to standard out */
	print_temp(tt);
}

/* AFWL */
#ifdef notdef
print_temp(tt)
float tt[];
{
	int i, nl;

	nl = NETC / 4;
	for ( i=0; i<nl; ++i )
	    printf("%10.3f%10.3f%10.3f%10.3f\n",
		tt[i],tt[i+nl],tt[i+2*nl],tt[i+3*nl]);
}
#endif

/* AFWL */
print_temp(tt)
float *tt;
{
	int row, col;
	int nrow;

	nrow = NETC / 8;
	if ( NETC%8 ) ++nrow;

	for ( row=0; row<nrow; ++row ) {
	    for ( col=0; col<8; ++col ) {
		printf("%8.2f",tt[row*8+col]);
	    }
	    printf("\n");
	}
	printf("\n");
}
#endif  /* AFWL */

net_setup(port,type,addr)
{
	short	stype, saddr;
	int sn;
	struct sockaddr_in sock;
	struct hostent *hp;
	struct netreq rbuf;

	if ( (sn=socket ( AF_INET, SOCK_STREAM, 0 )) < 0 )
	    return ( -1 );

/*	bzero((char *)&sock, sizeof(sock));	*/
	memset((char *)&sock, 0, sizeof(sock));
	sock.sin_family = AF_INET;
	if ( (hp=gethostbyname(mname)) == 0 )
	    return ( -2 );
/*	bcopy((char *) hp->h_addr,
	    (char *) &sock.sin_addr, hp->h_length);	*/
	memcpy( (char *) &sock.sin_addr,
	    (char *) hp->h_addr, hp->h_length);
	sock.sin_port = htons(port);

	/* Will hang in connect if trying to contact a
	 * non-existing machine (or one not on local net).
	 */
	if ( connect ( sn, (struct sockaddr *) &sock, sizeof(sock) ) < 0 )
	    return ( -3 );

	stype = type;
	saddr = addr;
	rbuf.ne_type = htons(stype);
	rbuf.ne_addr = htons(saddr);
	netwrite ( sn,&rbuf,sizeof(rbuf) );
	return ( sn );
}

netread(fd,buf,nbuf)
char *buf;
{
	int n, nleft;

	nleft = nbuf;
	while ( nleft ) {
	    if ( (n=read(fd,buf,nleft)) < 0 ) {
		printf("errno = %d\n",errno);
		printf("%d %d\n",n,nleft);
		return(-1);	/* error */
	    }
	    else if ( n == 0 )
		break;		/* EOF */
	    nleft -= n;
	    buf += n;
	}
	return (nbuf-nleft);
}

netwrite(fd,buf,nbuf)
char *buf;
{

	if ( write(fd,buf,nbuf) != nbuf )
	    return(-1);
	return (0);
}

/* simple version of readline, it would be better to do bigger reads and
 * buffer characters, rather than a system call per character read.
 */
readline(fd,buf,maxlen)
char *buf;
{
	int n, tot;

	for ( tot=0; tot<maxlen-1; ) {
	    if ( (n=read(fd,buf,1)) == 1 ) {
		if ( *buf == '\n' )
		    break;
		++tot;
		++buf;
	    } else if ( n == 0 ) {	/* EOF, the usual case */
		*buf = '\0';
		return ( tot );
	    } else {
		return ( -1 );
	    }
	}

	++tot;
	*++buf = '\0';
	return ( tot );
}

error(s)
char *s;
{
	fprintf(stderr,"%s\n",s);
	exit(1);
}

float
ntohf(float nval)
{
#if BYTE_ORDER == LITTLE_ENDIAN
	    union {
		long lval;
		float val;
	    } uval;

	uval.val = nval;
	uval.lval = ntohl(uval.lval);
	return ( uval.val );
#else
	return nval;
#endif
}

float
htonf(float hval)
{
#if BYTE_ORDER == LITTLE_ENDIAN
	    union {
		long lval;
		float val;
	    } uval;

	uval.val = hval;
	uval.lval = htonl(uval.lval);
	return ( uval.val );
#else
	return hval;
#endif
}
/* THE END */
