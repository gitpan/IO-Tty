#
# TODO:
#  probably should export ioctl constants
#

package IO::Tty;

use IO::Handle;
use IO::File;

require DynaLoader;

use vars qw(@ISA $VERSION $XS_VERSION);

$VERSION = $XS_VERSION = "0.94_01";
@ISA = qw(IO::Handle);

eval { require IO::Stty };
push @ISA, "IO::Stty" if (not $@);  # if IO::Stty is installed

BOOT_XS: {
    # If I inherit DynaLoader then I inherit AutoLoader and I DON'T WANT TO
    require DynaLoader;

    # DynaLoader calls dl_load_flags as a static method.
    *dl_load_flags = DynaLoader->can('dl_load_flags');

    do {
	defined(&bootstrap)
		? \&bootstrap
		: \&DynaLoader::bootstrap
    }->(__PACKAGE__);
}

sub import {
    IO::Tty::Constant->export_to_level(1, @_);
}

sub open {
    my($tty,$dev,$mode) = @_;

    IO::File::open($tty,$dev,$mode) or
	return undef;

    $tty->autoflush;

    1;
}

package IO::Tty::Constant;

use vars qw(@ISA @EXPORT_OK);
require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(B0 B110 B115200 B1200 B134 B150 B153600 B1800 B19200
	B200 B230400 B2400 B300 B307200 B38400 B460800 B4800 B50
	B57600 B600 B75 B76800 B9600 BRKINT BS0 BS1 BSDLY CBAUD
	CBAUDEXT CBRK CCTS_OFLOW CDEL CDSUSP CEOF CEOL CEOL2 CEOT
	CERASE CESC CFLUSH CIBAUD CIBAUDEXT CINTR CKILL CLNEXT CLOCAL
	CNSWTCH CNUL CQUIT CR0 CR1 CR2 CR3 CRDLY CREAD CRPRNT CRTSCTS
	CRTSXOFF CRTS_IFLOW CS5 CS6 CS7 CS8 CSIZE CSTART CSTOP CSTOPB
	CSUSP CSWTCH CWERASE DEFECHO DIOC DIOCGETP DIOCSETP DOSMODE
	ECHO ECHOCTL ECHOE ECHOK ECHOKE ECHONL ECHOPRT EXTA EXTB FF0
	FF1 FFDLY FIORDCHK FLUSHO HUPCL ICANON ICRNL IEXTEN IGNBRK
	IGNCR IGNPAR IMAXBEL INLCR INPCK ISIG ISTRIP IUCLC IXANY IXOFF
	IXON KBENABLED LDCHG LDCLOSE LDDMAP LDEMAP LDGETT LDGMAP LDIOC
	LDNMAP LDOPEN LDSETT LDSMAP LOBLK NCCS NL0 NL1 NLDLY NOFLSH
	OCRNL OFDEL OFILL OLCUC ONLCR ONLRET ONOCR OPOST PAGEOUT
	PARENB PAREXT PARMRK PARODD PENDIN RCV1EN RTS_TOG TAB0 TAB1
	TAB2 TAB3 TABDLY TCDSET TCFLSH TCGETA TCGETS TCIFLUSH TCIOFF
	TCIOFLUSH TCION TCOFLUSH TCOOFF TCOON TCSADRAIN TCSAFLUSH
	TCSANOW TCSBRK TCSETA TCSETAF TCSETAW TCSETCTTY TCSETS TCSETSF TCSETSW
	TCXONC TERM_D40 TERM_D42 TERM_H45 TERM_NONE TERM_TEC TERM_TEX
	TERM_V10 TERM_V61 TIOCCBRK TIOCCDTR TIOCEXCL TIOCCONS
	TIOCFLUSH TIOCGETC TIOCGETD TIOCGETP TIOCGLTC TIOCGPGRP
	TIOCGSID TIOCGSOFTCAR TIOCGWINSZ TIOCHPCL TIOCKBOF TIOCKBON
	TIOCLBIC TIOCLBIS TIOCLGET TIOCLSET TIOCMBIC TIOCMBIS TIOCMGET
	TIOCMSET TIOCM_CAR TIOCM_CD TIOCM_CTS TIOCM_DSR TIOCM_DTR
	TIOCM_LE TIOCM_RI TIOCM_RNG TIOCM_RTS TIOCM_SR TIOCM_ST
	TIOCNOTTY TIOCNXCL TIOCOUTQ TIOCREMOTE TIOCSBRK TIOCSDTR
	TIOCSETC TIOCSETD TIOCSETN TIOCSCTTY TIOCSETP TIOCSIGNAL
	TIOCSLTC TIOCSPGRP TIOCSSID TIOCSSOFTCAR TIOCSTART TIOCSTI
	TIOCSTOP TIOCSWINSZ TM_ANL TM_CECHO TM_CINVIS TM_LCF TM_NONE
	TM_SET TM_SNL TOSTOP VCEOF VCEOL VDISCARD VDSUSP VEOF VEOL
	VEOL2 VERASE VINTR VKILL VLNEXT VMIN VQUIT VREPRINT VSTART
	VSTOP VSUSP VSWTCH VT0 VT1 VTDLY VTIME VWERASE WRAP XCASE
	XCLUDE XMT1EN XTABS );

1;

__END__

=head1 NAME

IO::Tty - Low-level allocate a pseudo-Tty

=head1 VERSION

0.94_01 BETA

=head1 SYNOPSIS

    use IO::Tty;
    ...
    # don't use, see IO::Pty for a better way to create ptys.

=head1 DESCRIPTION

C<IO::Tty> is used internally by C<IO::Pty> to create a pseudo-tty.
You wouldn't want to use it directly, use C<IO::Pty>.

Windows is now supported (under the Cygwin environment, see
http://source.redhat.com/cygwin).

Please note that pty creation is very system-dependend.  From my
experience, any modern POSIX system should be fine.  Find below a
list of systems that IO::Tty should work on.

If you have problems on your system and your system is listed in the
"verified" list, you probably have some non-standard setup, e.g. you
compiled your Linux-kernel yourself and disabled ptys (bummer!).
Please ask your friendly sysadmin for help.

If your system is not listed, unpack the latest version of IO::Tty, do
a C<'perl Makefile.PL; make; make test; uname -a'> and send me
(F<RGiersig@cpan.org>) the results and I'll see what I can deduce from
that.

If it's working on your system, please send me a short note with
details (version number, distribution, etc. C<'uname -a'> is a good
start) so I can get an overview.  Thanks!


=head1 VERIFIED SYSTEMS, KNOWN ISSUES

This is a list of systems that IO::Tty seems to work on ('make test'
passes) with comments about "features":

=over 4

=item * Linux 2.2.x & 2.4.0 (Redhat 6.2 & 7.0, Suse 7.x)

=item * AIX 4.3

=item * FreeBSD 4.3

=item * OpenBSD 2.8

The ioctl TIOCSCTTY sometimes fails.  This is also known in
Tcl/Expect, see http://expect.nist.gov/FAQ.html

=item * SCO Unix v??

=item * HPUX 10.20 & 11.00

There seems to be no way to send an EOF from the slave to the master,
so a parent process might not notice that the child went away.

=item * OSF 4.0

=item * Solaris 2.6 & 8

=item * Windows NT/2k (under Cygwin)

Seems to have buggy ptys: when you send (print) a too large string
(some hundred bytes) to the pty, the call may just hang forever and
even alarm() cannot get you out.  Don't complain to me...

=back

If you have additions to these lists, please mail them to
E<lt>F<RGiersig@cpan.org>E<gt>.


=head1 SEE ALSO

L<IO::Pty>, L<Expect>

=head1 MAILING LISTS

As this module is mainly used by Expect, support for it is available
via the two Expect mailing lists, expectperl-announce and
expectperl-discuss, at

  http://lists.sourceforge.net/lists/listinfo/expectperl-announce

and

  http://lists.sourceforge.net/lists/listinfo/expectperl-discuss


=head1 AUTHORS

Originally by Graham Barr E<lt>F<gbarr@pobox.com>E<gt>, based on the
Ptty module by Nick Ing-Simmons E<lt>F<nik@tiuk.ti.com>E<gt>.

Now maintained and heavily rewritten by Roland Giersig
E<lt>F<RGiersig@cpan.org>E<gt>.

Contains copyrighted stuff from openssh v3.0p1, authored by Tatu
Ylonen <ylo@cs.hut.fi>, Markus Friedl and Todd C. Miller
<Todd.Miller@courtesan.com>.  I also got a lot of inspiry from the pty
code in Xemacs.


=head1 COPYRIGHT

Now all code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Nevertheless the above AUTHORS retain their copyrights to the various
parts and want to receive credit if their source code is used.
See the source for details.


=head1 DISCLAIMER

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.

=cut
