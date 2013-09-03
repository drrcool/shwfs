/* functions to support paths relative to HOME, other misc io. */

#include <stdio.h>
#include <ctype.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#include "P_.h"
#include "astro.h"
#include "circum.h"

extern void db_write_line P_((Obj *op, char line[]));
extern void xe_msg P_((char *msg, int app_modal));

/* if path starts with `~' replace with $HOME.
 * we also remove any leading or trailing blanks, and trailing / or \
 * caller should save returned string before calling us again.
 */
char *
expand_home (path)
char *path;
{
	static char *mpath;
	static char *home;
	static int homel;
	char *p;
	int l;

	/* get home, if we don't already know it */
	if (!home) {
	    home = getenv ("HOME");
	    if (home)
		homel = strlen (home);
	}

	/* start mpath so we can always just use realloc */
	if (!mpath)
	    mpath = malloc (1);

	/* skip leading blanks */
	l = strlen (path);
	while (*path == ' ') {
	    path++;
	    l--;
	}

	/* move '\0' back past any trailing baggage */
	for (p = &path[l-1]; p >= path; --l)
	    if (*p == ' ' || *p == '/' || *p == '\\')
		*p-- = '\0';
	    else
		break;

	/* prepend home if starts with ~ */
	if (path[0] == '~' && home)
	    sprintf (mpath = realloc (mpath, homel+l), "%s%s", home, path+1);
	else
	    strcpy (mpath = realloc(mpath, l+1), path);

	return (mpath);
}

/* like fopen() but substitutes HOME if name starts with '~'
 */
FILE *
fopenh (name, how)
char *name;
char *how;
{
	return (fopen (expand_home(name), how));
}

/* like open(2) but substitutes HOME if name starts with '~'.
 */
int
openh (name, flags, perm)
char *name;
int flags;
int perm;
{
	return (open (expand_home(name), flags, perm));
}

/* return 0 if the given file exists, else -1.
 * substitute HOME if name starts with '~'.
 */
int
existsh (name)
char *name;
{
	struct stat s;

	return (stat (expand_home(name), &s));
}

/* get the anchor for all of xephem's support files.
 * use TELHOME env first, else ShareDir X resource, else current dir.
 */
char *
getShareDir()
{
	static char *basedir;

	if (!basedir) {
	    char *th = getenv ("TELHOME");
	    if (th) {
		basedir = malloc (strlen(th) + 10);
		if (basedir) {
		    (void) sprintf (basedir, "%s/xephem", th);
		    if (existsh(basedir) < 0) {
			(void) sprintf (basedir, "%s/archive", th);
			if (existsh(basedir) < 0) {
			    free (basedir);
			    basedir = NULL;
			}
		    }
		}
	    }
	    if (!basedir) {
	      char *homebase = expand_home ("/usr/share/xephem");
	      basedir = strcpy(malloc(strlen(homebase)+1), homebase);
	    }
	}

	return (basedir);

}

/* return a string for whatever is in errno right now.
 * I never would have imagined it would be so crazy to turn errno into a string!
 */
char *
syserrstr ()
{
#if defined(__STDC__)
/* some older gcc don't have strerror */
#include <errno.h>
return (strerror (errno));
#else
#if defined(VMS)
#include <errno.h>
#include <perror.h>
#else
#if !defined(__FreeBSD__) && !defined(__EMX__)
/* this is aready in stdio.h on FreeBSD */
/* this is already in stdlib.h in EMX   M. Goldberg 27 January 1997 for OS/2 */
extern char *sys_errlist[];
#endif
extern int errno;
#endif
return (sys_errlist[errno]);
#endif
}

/* For RCS Only -- Do Not Edit */
static char *rcsid[2] = {(char *)rcsid, "@(#) $RCSfile: homeio.c,v $ $Date: 2001/10/22 07:14:22 $ $Revision: 1.11 $ $Name:  $"};
