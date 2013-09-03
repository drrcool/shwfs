/*                                                                -*-c-*- 
    Copyright (C) 1996 Gregory D. Hager, Alfred A. Rizzi and Noah J. Cowan

    Permission is granted to any individual or institution to use, copy, 
    modify, and distribute this software, provided that this complete 
    copyright and permission notice is maintained, intact, in all copies 
    and supporting documentation.  Authors of papers that describe software 
    systems using this software package are asked to acknowledge such use
    by a brief statement in the paper.

    Gregory D. Hager, Alfred A. Rizzi and Noah J. Cowan provide this
    software "as is" without express or implied warranty.

    Authors : Gregory D. Hager  ??/??
              Alfred A. Rizzi   ??/??
              Noah J. Cowan     ??/??
              Jason LaPenta     01/2000

-- Changes --

  Date        By  Description of changes made
  -------------------------------------------------------------------
  24-Feb-2000 JML Modifed to work with new driver and removed
                  unnecessary header files
  04-Jul-2002 SS  Bugfix to work out-of-the-box when driver using CCIR mode
                  (thanks to Greg Sharp for spotting this one); Fix formatting;
		  General tidy-up; Bugfix: explicitly set (frame/field) mode
		  as the mode is 'remembered' across invocations of this
		  program.
*/

#include <stdio.h>
#include <stdlib.h> /* exit() */

#include <dt3155.h>
#include <dt3155_lib.h>
#include <fitsio.h>

#define DEVICE 0

#ifdef CCIR
#define FORMAT FORMAT_CCIR
#else
#define FORMAT FORMAT_NTSC
#endif

int main (void)
{
  int i, status;
	fitsfile *fptr;
	char fname[20];
	struct dt3155_status_s dt3155_status;
	u_int columns = DT3155_MAX_COLS, rows = DT3155_MAX_ROWS;
	dt3155_info_t *fb_info;
	long nelements, naxes[2];

	status = 0;
	naxes[0] = 640;
	naxes[1] = 480;
	nelements = naxes[0]*naxes[1];

	/* find board and get it open */
	if ((fb_info = dt3155_open(FORMAT, 0, DEVICE)) == NULL)
		exit(0);

	/* initialize hardware */
	if (dt3155Init(fb_info)) 
	  //		printf("DT3155 successfully initialized\n");

	for (i = 0; i < 5; ++i)
	{
	  //		printf("Buffer %d is at 0x%lx \n", i + 1, fb_info->memory_phys_addresses[i]);
	}

	if (ioctl(fb_info->fd, DT3155_GET_CONFIG, &dt3155_status) < 0)
	{
		perror("ioctl failed");
		exit(1);
	}

	/*
	 * set board to work in appropriate mode.
	 * (by default device driver starts board in FRAME mode, so if you
	 * never change modes & you always want to use FRAME mode your app
	 * does not have to make these ioctl() calls.)
	 */
	dt3155_status.config.acq_mode = (DT3155_MODE_FRAME);
	dt3155_status.config.cols = columns;
	dt3155_status.config.rows = rows;

	if (ioctl(fb_info->fd, DT3155_SET_CONFIG, &dt3155_status.config) < 0)
	{
		perror("ioctl failed");
		exit(1);
	}

	if (!dt3155Acquire_poll(fb_info, 1))
	  {
	    printf("Screwed up!\n");
	    exit(0);
	  }
	sprintf(fname, "stella.fits");
	fits_create_file(&fptr, fname, &status);
	fits_create_img(fptr, BYTE_IMG, 2, naxes, &status);
	//	printf("Writing file %s\n", fname);
	fits_write_img(fptr, TBYTE, 1, nelements, fb_info->memory_log_addresses[0], &status);
	
	fits_close_file(fptr, &status);
	fits_report_error(stderr, status);

	dt3155_close(fb_info);
	return status;
}
