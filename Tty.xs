#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define PTY_DEBUG 1

#ifdef PerlIO
typedef int SysRet;
typedef PerlIO * InOutStream;
#else
# define PERLIO_IS_STDIO 1
# define PerlIO_fileno fileno
typedef int SysRet;
typedef FILE * InOutStream;
#endif

/*
 * Define an XSUB that returns a constant scalar. The resulting structure is
 * identical to that created by the parser when it parses code like :
 *
 *    sub xyz () { 123 }
 *
 * This allows the constants from the XSUB to be inlined.
 *
 * !!! THIS SHOULD BE ADDED INTO THE CORE CODE !!!!
 *
 */

#include "patchlevel.h"

#if (PATCHLEVEL < 3) || ((PATCHLEVEL == 3) && (SUBVERSION < 22))
     /* before 5.003_22 */
#    define MY_start_subparse(fmt,flags) start_subparse()
#else
#  if (PATCHLEVEL == 3) && (SUBVERSION == 22)
     /* 5.003_22 */
#    define MY_start_subparse(fmt,flags) start_subparse(flags)
#  else
     /* 5.003_23  onwards */
#    define MY_start_subparse(fmt,flags) start_subparse(fmt,flags)
#  endif
#endif

#ifndef newCONSTSUB
static void
newCONSTSUB(stash,name,sv)
    HV *stash;
    char *name;
    SV *sv;
{
#ifdef dTHR
    dTHR;
#endif
    U32 oldhints = hints;
    HV *old_cop_stash = curcop->cop_stash;
    HV *old_curstash = curstash;
    line_t oldline = curcop->cop_line;
    curcop->cop_line = copline;

    hints &= ~HINT_BLOCK_SCOPE;
    if(stash)
	curstash = curcop->cop_stash = stash;

    newSUB(
	MY_start_subparse(FALSE, 0),
	newSVOP(OP_CONST, 0, newSVpv(name,0)),
	newSVOP(OP_CONST, 0, &sv_no),	/* SvPV(&sv_no) == "" -- GMB */
	newSTATEOP(0, Nullch, newSVOP(OP_CONST, 0, sv))
    );

    hints = oldhints;
    curcop->cop_stash = old_cop_stash;
    curstash = old_curstash;
    curcop->cop_line = oldline;
}
#endif

/*
 * The following pty-allocation code was heavily inspired by its
 * counterparts in openssh 3.0p1 and Xemacs 21.4.5 but is a complete
 * rewrite by me, Roland Giersig <RGiersig@cpan.org>.
 *
 * Nevertheless my references to Tatu Ylonen <ylo@cs.hut.fi>
 * and the Xemacs development team for their inspiring code.
 *
 * mysignal and strlcpy were borrowed from openssh and have their
 * copyright messages attached.
 */

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>

#ifdef HAVE_LIBUTIL_H
# include <libutil.h>
#endif /* HAVE_UTIL_H */

#ifdef HAVE_UTIL_H
# include <util.h>
#endif /* HAVE_UTIL_H */

#ifdef HAVE_PTY_H
# include <pty.h>
#endif

#if defined(HAVE_DEV_PTMX) && defined(HAVE_SYS_STROPTS_H)
# include <sys/stropts.h>
#endif

#ifndef O_NOCTTY
#define O_NOCTTY 0
#endif


/* from  $OpenBSD: misc.c,v 1.12 2001/06/26 17:27:24 markus Exp $        */

/*
 * Copyright (c) 2000 Markus Friedl.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <signal.h>

typedef void (*mysig_t)(int);

static mysig_t
mysignal(int sig, mysig_t act)
{
#ifdef HAVE_SIGACTION
        struct sigaction sa, osa;

        if (sigaction(sig, NULL, &osa) == -1)
                return (mysig_t) -1;
        if (osa.sa_handler != act) {
                memset(&sa, 0, sizeof(sa));
                sigemptyset(&sa.sa_mask);
                sa.sa_flags = 0;
#if defined(SA_INTERRUPT)
                if (sig == SIGALRM)
                        sa.sa_flags |= SA_INTERRUPT;
#endif
                sa.sa_handler = act;
                if (sigaction(sig, &sa, NULL) == -1)
                        return (mysig_t) -1;
        }
        return (osa.sa_handler);
#else
        return (signal(sig, act));
#endif
}

/*  from  $OpenBSD: strlcpy.c,v 1.5 2001/05/13 15:40:16 deraadt Exp $     */

/*
 * Copyright (c) 1998 Todd C. Miller <Todd.Miller@courtesan.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef HAVE_STRLCPY

/*
 * Copy src to string dst of size siz.  At most siz-1 characters
 * will be copied.  Always NUL terminates (unless siz == 0).
 * Returns strlen(src); if retval >= siz, truncation occurred.
 */
static size_t
strlcpy(dst, src, siz)
        char *dst;
        const char *src;
        size_t siz;
{
        register char *d = dst;
        register const char *s = src;
        register size_t n = siz;

        /* Copy as many bytes as will fit */
        if (n != 0 && --n != 0) {
                do {
                        if ((*d++ = *s++) == 0)
                                break;
                } while (--n != 0);
        }

        /* Not enough room in dst, add NUL and traverse rest of src */
        if (n == 0) {
                if (siz != 0)
                        *d = '\0';              /* NUL-terminate dst */
                while (*s++)
                        ;
        }

        return(s - src - 1);    /* count does not include NUL */
}

#endif /* !HAVE_STRLCPY */


/*
 * After having acquired a master pty, try to find out the slave name,
 * initialize and open the slave.
 */

#if defined (HAVE_PTSNAME)
char * ptsname(int);
#endif

static int
open_slave(int *ptyfd, int *ttyfd, char *namebuf, int namebuflen)
{ 
    /*
     * now do some things that are supposedly healthy for ptys,
     * i.e. changing the access mode.
     */
#if defined(HAVE_GRANTPT) ||  defined(HAVE_UNLOCKPT)
    {
	mysig_t old_signal;
	old_signal = mysignal(SIGCHLD, SIG_DFL);
#if defined(HAVE_GRANTPT)
#if PTY_DEBUG
	fprintf(stderr, "trying grantpt()...\n");
#endif
	if (grantpt(*ptyfd) < 0) {
	    if (PL_dowarn)
		warn("IO::Tty::pty_allocate(nonfatal): grantpt(): %.100s", strerror(errno));
	}
#endif /* HAVE_GRANTPT */
#if defined(HAVE_UNLOCKPT)
#if PTY_DEBUG
	fprintf(stderr, "trying unlockpt()...\n");
#endif
	if (unlockpt(*ptyfd) < 0) {
	    if (PL_dowarn)
		warn("IO::Tty::pty_allocate(nonfatal): unlockpt(): %.100s", strerror(errno));
	}
#endif /* HAVE_UNLOCKPT */
	mysignal(SIGCHLD, old_signal);
    } 
#endif /* HAVE_GRANTPT || HAVE_UNLOCKPT */
 

    /*
     * find the slave name, if we don't have it already
     */
    
#if defined (HAVE_PTSNAME_R)
    if (namebuf[0] == 0) {
#if PTY_DEBUG
	fprintf(stderr, "trying ptsname_r()...\n");
#endif
	if(ptsname_r(*ptyfd, namebuf, namebuflen)) {
	    if (PL_dowarn)
		warn("IO::Tty::open_slave(nonfatal): ptsname_r(): %.100s", strerror(errno));
	}
    }
#endif /* HAVE_PTSNAME_R */

#if defined (HAVE_PTSNAME)
    if (namebuf[0] == 0) {
	char * name;
#if PTY_DEBUG
	fprintf(stderr, "trying ptsname()...\n");
#endif
	name = ptsname(*ptyfd);
	if (name) {
	    strlcpy(namebuf, name, namebuflen);
	} else {
	    if (PL_dowarn)
		warn("IO::Tty::open_slave(nonfatal): ptsname(): %.100s", strerror(errno));
	}
    }
#endif /* HAVE_PTSNAME */

    if (namebuf[0] == 0)
	return 0;		/* we failed to get the slave name */

    if (*ttyfd >= 0)
      return 1;			/* we already have an open slave, so
                                   no more init is needed */

    /*
     * Open the slave side.
     */
#if PTY_DEBUG
    fprintf(stderr, "trying to open %s...\n", namebuf);
#endif

    *ttyfd = open(namebuf, O_RDWR | O_NOCTTY);
    if (*ttyfd < 0) {
      if (PL_dowarn)
	warn("IO::Tty::open_slave(nonfatal): open(%.200s): %.100s",
	     namebuf, strerror(errno));
      close(*ptyfd);
      return 0;		/* too bad, couldn't open slave side */
    }

#if defined (I_PUSH)
    /*
     * Push appropriate streams modules for Solaris pty(7).
     * HP-UX pty(7) doesn't have ttcompat module.
     * We simply try to push all relevant modules but warn only on
     * those platforms we know these are required.
     */
#if PTY_DEBUG
    fprintf(stderr, "trying to I_PUSH ptem...\n");
#endif
    if (ioctl(*ttyfd, I_PUSH, "ptem") < 0)
#if defined (__solaris) || defined(__hpux)
	if (PL_dowarn)
	    warn("IO::Tty::pty_allocate: ioctl I_PUSH ptem: %.100s", strerror(errno))
#endif
	      ;

#if PTY_DEBUG
    fprintf(stderr, "trying to I_PUSH ldterm...\n");
#endif
    if (ioctl(*ttyfd, I_PUSH, "ldterm") < 0)
#if defined (__solaris) || defined(__hpux)
	if (PL_dowarn)
	    warn("IO::Tty::pty_allocate: ioctl I_PUSH ldterm: %.100s", strerror(errno))
#endif
	      ;

#if PTY_DEBUG
    fprintf(stderr, "trying to I_PUSH ttcompat...\n");
#endif
    if (ioctl(*ttyfd, I_PUSH, "ttcompat") < 0)
#if defined (__solaris)
	if (PL_dowarn)
	    warn("IO::Tty::pty_allocate: ioctl I_PUSH ttcompat: %.100s", strerror(errno))
#endif
	      ;
#endif /* I_PUSH */

    return 1;
}

/*
 * Allocates and opens a pty.  Returns 0 if no pty could be allocated, or
 * nonzero if a pty was successfully allocated.  On success, open file
 * descriptors for the pty and tty sides and the name of the tty side are
 * returned (the buffer must be able to hold at least 64 characters).
 *
 * Instead of trying just one method we go through all available
 * methods until we get a positive result.
 */

static int
allocate_pty(int *ptyfd, int *ttyfd, char *namebuf, int namebuflen)
{
    *ptyfd = -1;
    *ttyfd = -1;
    namebuf[0] = 0;

    /*
     * first we try to get a master device
     */
    do { /* we use do{}while(0) and break instead of goto */

#if defined(HAVE__GETPTY)
	/* _getpty(3) for SGI Irix */
	{
	    char *slave;
	    mysig_t old_signal;

#if PTY_DEBUG
	    fprintf(stderr, "trying _getpty()...\n");
#endif
	    /* _getpty spawns a suid prog, so don't ignore SIGCHLD */
    	    old_signal = mysignal(SIGCHLD, SIG_DFL);
	    slave = _getpty(ptyfd, O_RDWR, 0622, 0);
	    mysignal(SIGCHLD, old_signal);

	    if (slave != NULL) {
	        strlcpy(namebuf, slave, namebuflen);
		if (open_slave(ptyfd, ttyfd, namebuf, namebuflen))
		    break;
		close(ptyfd);
		*ptyfd = -1;
	    } else {
		if (PL_dowarn)
		    warn("pty_allocate(nonfatal): _getpty(): %.100s", strerror(errno));
		*ptyfd = -1;
	    }
	}
#endif

	/*
	 * now try various cloning devices
	 */

#if defined(HAVE_DEV_PTMX)
#if PTY_DEBUG
	fprintf(stderr, "trying /dev/ptmx...\n");
#endif

	*ptyfd = open("/dev/ptmx", O_RDWR | O_NOCTTY);
	if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
	    break;
	if (PL_dowarn)
	    warn("pty_allocate(nonfatal): open(/dev/ptmx): %.100s", strerror(errno));
#endif /* HAVE_DEV_PTMX */ 

#if defined(HAVE_DEV_PTYM_CLONE)
#if PTY_DEBUG
	fprintf(stderr, "trying /dev/ptym/clone...\n");
#endif

	*ptyfd = open("/dev/ptym/clone", O_RDWR | O_NOCTTY);
	if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
	    break;
	if (PL_dowarn)
	    warn("pty_allocate(nonfatal): open(/dev/ptym/clone): %.100s", strerror(errno));
#endif /* HAVE_DEV_PTYM_CLONE */

#if defined(HAVE_DEV_PTC)
	/* AIX-style pty code. */
#if PTY_DEBUG
	fprintf(stderr, "trying /dev/ptc...\n");
#endif

	*ptyfd = open("/dev/ptc", O_RDWR | O_NOCTTY);
	if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
	    break;
	if (PL_dowarn)
	    warn("pty_allocate(nonfatal): open(/dev/ptc): %.100s", strerror(errno));
#endif /* HAVE_DEV_PTC */

#if defined(HAVE_DEV_PTMX_BSD)
#if PTY_DEBUG
	fprintf(stderr, "trying /dev/ptmx_bsd...\n");
#endif
	*ptyfd = open("/dev/ptmx_bsd", O_RDWR | O_NOCTTY);
	if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
	    break;
	if (PL_dowarn)
	    warn("pty_allocate(nonfatal): open(/dev/ptmx_bsd): %.100s", strerror(errno));
#endif /* HAVE_DEV_PTMX_BSD */ 

	/* try high-level stuff */

#if defined(HAVE_OPENPTY)
	/* openpty(3) exists in a variety of OS'es */
	{
	    mysig_t old_signal;
	    int ret;
	    char name[PATH_MAX+1];

#if PTY_DEBUG
	    fprintf(stderr, "trying openpty()...\n");
#endif
	    old_signal = mysignal(SIGCHLD, SIG_DFL);
	    ret = openpty(ptyfd, ttyfd, name, NULL, NULL);
	    mysignal(SIGCHLD, old_signal);
	    if (ret >= 0 && *ptyfd >= 0) {
	        strlcpy(namebuf, name, namebuflen);
		if (open_slave(ptyfd, ttyfd, namebuf, namebuflen))
		    break;
	    }
	    *ptyfd = -1;
	    *ttyfd = -1;
	    if (PL_dowarn)
		warn("pty_allocate(nonfatal): openpty(): %.100s", strerror(errno));
	}
#endif

#if defined(HAVE_GETPT)
	/* glibc defines this */
#if PTY_DEBUG
	fprintf(stderr, "trying getpt()...\n");
#endif
	*ptyfd = getpt();
	if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
	    break;		/* got one */
	if (PL_dowarn)
	    warn("pty_allocate(nonfatal): getpt(): %.100s", strerror(errno));
#endif

	/*
	 * we still don't have a pty, so try some oldfashioned stuff, 
	 * looking for a pty ourself.
	 */

#if defined(_CRAY)
	{
	    char buf[64];
	    int i;
	    int highpty;
	    
#ifdef _SC_CRAY_NPTY
	    highpty = sysconf(_SC_CRAY_NPTY);
	    if (highpty == -1)
		highpty = 128;
#else
	    highpty = 128;
#endif
#if PTY_DEBUG
	    fprintf(stderr, "trying CRAY /dev/pty/???...\n");
#endif
	    for (i = 0; i < highpty; i++) {
		snprintf(buf, sizeof(buf), "/dev/pty/%03d", i);
		*ptyfd = open(buf, O_RDWR | O_NOCTTY);
		if (*ptyfd < 0)
		    continue;
		snprintf(namebuf, namebuflen, "/dev/ttyp%03d", i);
		break;
	    }
	    if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
		break;
	}
#endif

#if defined(HAVE_DEV_PTYM)
	{
	    /* HPUX */
	    char buf[64];
	    int i;
	    struct stat sb;
	    const char *ptymajors = "abcefghijklmnopqrstuvwxyz";
	    const char *ptyminors = "0123456789abcdef";
	    int num_minors = strlen(ptyminors);
	    int num_ptys = strlen(ptymajors) * num_minors;
	    
#if PTY_DEBUG
	    fprintf(stderr, "trying HPUX /dev/ptym/pty[a-ce-z][0-9a-f]...\n");
#endif
	    /* try /dev/ptym/pty[a-ce-z][0-9a-f] */
	    for (i = 0; i < num_ptys; i++) {
		snprintf(buf, sizeof buf, "/dev/ptym/pty%c%c",
			 ptymajors[i / num_minors],
			 ptyminors[i % num_minors]);
		snprintf(namebuf, namebuflen, "/dev/pty/tty%c%c",
			 ptymajors[i / num_minors],
			 ptyminors[i % num_minors]);
		if(stat(buf, &sb))
		    break;	/* file does not exist, skip rest */
		*ptyfd = open(buf, O_RDWR | O_NOCTTY);
		if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
		    break;
		namebuf[0] = 0;
	    }
	    if (*ptyfd >= 0)
		break;

#if PTY_DEBUG
	    fprintf(stderr, "trying HPUX /dev/ptym/pty[a-ce-z][0-9][0-9]...\n");
#endif
	    /* now try /dev/ptym/pty[a-ce-z][0-9][0-9] */
	    num_minors = 100;
	    num_ptys = strlen(ptymajors) * num_minors;
	    for (i = 0; i < num_ptys; i++) {
		snprintf(buf, sizeof buf, "/dev/ptym/pty%c%02d",
			 ptymajors[i / num_minors],
			 i % num_minors);
		snprintf(namebuf, namebuflen, "/dev/pty/tty%c%02d",
			 ptymajors[i / num_minors], i % num_minors);
		
		if(stat(buf, &sb))
		    break;	/* file does not exist, skip rest */
		*ptyfd = open(buf, O_RDWR | O_NOCTTY);
		if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
		    break;
		namebuf[0] = 0;
	    }
	    if (*ptyfd >= 0)
		break;
	}
#endif /* HAVE_DEV_PTYM */

	{
	    /* BSD-style pty code. */
	    char buf[64];
	    int i;
	    const char *ptymajors = "pqrstuvwxyzabcdefghijklmnoABCDEFGHIJKLMNOPQRSTUVWXYZ";
	    const char *ptyminors = "0123456789abcdef";
	    int num_minors = strlen(ptyminors);
	    int num_ptys = strlen(ptymajors) * num_minors;

#if PTY_DEBUG
	    fprintf(stderr, "trying BSD /dev/pty??...\n");
#endif
	    for (i = 0; i < num_ptys; i++) {
		snprintf(buf, sizeof buf, "/dev/pty%c%c",
			 ptymajors[i / num_minors],
			 ptyminors[i % num_minors]);
		snprintf(namebuf, namebuflen, "/dev/tty%c%c",
			 ptymajors[i / num_minors],
			 ptyminors[i % num_minors]);
		*ptyfd = open(buf, O_RDWR | O_NOCTTY);
		if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
		    break;
		/* Try SCO style naming */
		snprintf(buf, sizeof buf, "/dev/ptyp%d", i);
		snprintf(namebuf, namebuflen, "/dev/ttyp%d", i);
		*ptyfd = open(buf, O_RDWR | O_NOCTTY);
		if (*ptyfd >= 0 && open_slave(ptyfd, ttyfd, namebuf, namebuflen))
		    break;
		namebuf[0] = 0;
	    }
	    if (*ptyfd >= 0)
		break;
	}

    } while (0);

    if (*ptyfd < 0 || namebuf[0] == 0)
	return 0;		/* we failed to allocate one */

    return 1;			/* whew, finally finished successfully */
} /* end allocate_pty */



MODULE = IO::Tty	PACKAGE = IO::Pty

PROTOTYPES: DISABLE

void
pty_allocate()
    INIT:
	int ptyfd, ttyfd, ret;
	char name[256];

    PPCODE:
	ret = allocate_pty(&ptyfd, &ttyfd, name, sizeof(name));
	if (ret) {
	    name[sizeof(name)-1] = 0;
	    EXTEND(SP,3);
	    PUSHs(sv_2mortal(newSViv(ptyfd)));	
	    PUSHs(sv_2mortal(newSViv(ttyfd)));	
	    PUSHs(sv_2mortal(newSVpv(name, strlen(name))));	
        } else {
	    /* empty list */
	}


MODULE = IO::Tty	PACKAGE = IO::Tty

char *
ttyname(handle)
InOutStream handle
    CODE:
#ifdef HAVE_TTYNAME
	if (handle)
	    RETVAL = ttyname(PerlIO_fileno(handle));
	else {
	    RETVAL = Nullch;
	    errno = EINVAL;
	}
#else
#ifdef HAVE_PTSNAME
	if (handle)
	    RETVAL = ptsname(PerlIO_fileno(handle));
	else {
	    RETVAL = Nullch;
	    errno = EINVAL;
	}
#else
	warn("IO::Tty::ttyname not implemented on this architecture");
	RETVAL = Nullch;
#endif
#endif
    OUTPUT:
	RETVAL


BOOT:
{
  HV *stash;
  SV *config;
  
  stash = gv_stashpv("IO::Tty::Constant", TRUE);
  config = perl_get_sv("IO::Tty::CONFIG", TRUE);    
#include "xssubs.c"
}


