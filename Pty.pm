# Documentation at the __END__

package IO::Pty;

use strict;
use Carp;
use IO::Tty qw(TIOCSCTTY TCSETCTTY TIOCNOTTY);
use IO::File;
require POSIX;

use vars qw(@ISA $VERSION);

$VERSION = $IO::Tty::VERSION;

@ISA = qw(IO::Handle);

sub new {
  my ($class) = $_[0] || "IO::Pty";
  $class = ref($class) if ref($class);
  @_ <= 1 or croak 'usage: new $class';

  my ($ptyfd, $ttyfd, $ttyname) = pty_allocate();

  croak "Cannot open a pty" if not defined $ptyfd;

  my $pty = $class->SUPER::new_from_fd($ptyfd, "r+");
  croak "Cannot create a new $class from fd $ptyfd: $!" if not $pty;
  $pty->autoflush(1);
  bless $pty => $class;

  my $slave = IO::Tty->new_from_fd($ttyfd, "r+");
  croak "Cannot create a new IO::Tty from fd $ttyfd: $!" if not $slave;
  $slave->autoflush(1);

  ${*$pty}{'io_pty_slave'} = $slave;
  ${*$pty}{'io_pty_ttyname'} = $ttyname;
  ${*$slave}{'io_tty_ttyname'} = $ttyname;

  return $pty;
}

sub ttyname {
  @_ == 1 or croak 'usage: $pty->ttyname();';
  my $pty = shift;
  ${*$pty}{'io_pty_ttyname'};
}


sub close_slave {
  @_ == 1 or croak 'usage: $pty->close_slave();';

  my $master = shift;

  if (exists ${*$master}{'io_pty_slave'}) {
    close ${*$master}{'io_pty_slave'};
    delete ${*$master}{'io_pty_slave'};
  }
}

sub slave {
  @_ == 1 or croak 'usage: $pty->slave();';

  my $master = shift;

  if (exists ${*$master}{'io_pty_slave'}) {
    return ${*$master}{'io_pty_slave'};
  }

  my $tty = $master->ttyname();

  my $slave = new IO::Tty;

  $slave->open($tty, O_RDWR | O_NOCTTY) ||
    croak "Cannot open slave $tty: $!";

  return $slave;
}

sub make_slave_controlling_terminal {
  @_ == 1 or croak 'usage: $pty->make_slave_controlling_terminal();';

  my $self = shift;

  # loose controlling terminal explicitely
  if (defined TIOCNOTTY) {
    if (open (DEVTTY, "/dev/tty")) {
      ioctl( DEVTTY, TIOCNOTTY, 0 );
      close DEVTTY;
    }
  }

  # Create a new 'session', lose controlling terminal.
  if (not POSIX::setsid()) {
    warn "setsid() failed, strange behavior may result: $!\r\n" if $^W;
  }

  if (open(DEVTTY, "/dev/tty")) {
    warn "Could not disconnect from controlling terminal?!\n" if $^W;
    close DEVTTY;
  }

  # now open slave, this should set it as controlling tty on some systems
  my $ttyname = ${*$self}{'io_pty_ttyname'};
  my $slv = new IO::Tty;
  $slv->open($ttyname, O_RDWR)
    or croak "Cannot open slave $ttyname: $!";

  if (not exists ${*$self}{'io_pty_slave'}) {
    ${*$self}{'io_pty_slave'} = $slv;
  } else {
    $slv->close;
  }

  # Acquire a controlling terminal if this doesn't happen automatically
  if (defined TIOCSCTTY) {
    if (not defined ioctl( ${*$self}{'io_pty_slave'}, TIOCSCTTY, 0 )) {
      warn "warning: TIOCSCTTY failed, slave might not be set as controlling terminal: $!" if $^W;
    }
  } elsif (defined TCSETCTTY) {
    if (not defined ioctl( ${*$self}{'io_pty_slave'}, TCSETCTTY, 0 )) {
      warn "warning: TCSETCTTY failed, slave might not be set as controlling terminal: $!" if $^W;
    }
  }

  if (not open(DEVTTY, "/dev/tty")) {
    croak "Could not connect pty as controlling terminal!\n";
  } else {
    close DEVTTY;
  }
  
  return 1;
}


1;

__END__

=head1 NAME

IO::Pty - Pseudo TTY object class

=head1 VERSION

0.94_02 BETA

=head1 SYNOPSIS

    use IO::Pty;

    $pty = new IO::Pty;

    $slave  = $pty->slave;

    foreach $val (1..10) {
	print $pty "$val\n";
	$_ = <$slave>;
	print "$_";
    }

    close($slave);


=head1 DESCRIPTION

C<IO::Pty> provides an interface to allow the creation of a pseudo tty.

C<IO::Pty> inherits from C<IO::Handle> and so provide all the methods
defined by the C<IO::Handle> package.

Please note that pty creation is very system-dependend.  If you have
problems, see L<IO::Tty> for help.


=head1 CONSTRUCTOR

=over 3

=item new

The C<new> constructor takes no arguments and returns a new file
object which is the master side of the pseudo tty.

=back

=head1 METHODS

=over 4

=item ttyname

Returns the name of the slave pseudo tty. On UNIX machines this will
be the pathname of the device.  Use this name for informational
purpose only, to get a slave filehandle, use slave().

=item slave

The C<slave> method will return the slave filehandle of the given
master pty, opening it anew if necessary.  If IO::Stty is installed,
you can then call $slave->stty() to modify the terminal settings.

=item close_slave

The slave filehandle will be closed and destroyed.  This is necessary
in the parent after forking to get rid of the open filehandle,
otherwise the parent will not notice if the child exits.

=item make_slave_controlling_terminal

This will set the slave filehandle as the controlling terminal of the
current process, which will become a session leader, so this should
only be called by a child process after a fork(), e.g. in the callback
to sync_exec() (see L<Proc::SyncExec>).

=back


=head1 SEE ALSO

L<IO::Tty>, L<IO::Handle>, L<Expect>, L<Proc::SyncExec>


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

Contains copyrighted stuff from openssh v3.0p1, authored by 
Tatu Ylonen <ylo@cs.hut.fi>, Markus Friedl and Todd C. Miller
<Todd.Miller@courtesan.com>.


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

