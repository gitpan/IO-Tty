# Documentation at the __END__
# Based on original Ptty package by Nick Ing-Simmons
# heavily remodeled after the Tcl/Expect pty creation by Don Libes

package IO::Pty;

use strict;
use Carp;
use IO::Tty qw(TIOCSCTTY TCSETCTTY TIOCNOTTY);
use IO::File;
require POSIX;

use vars qw(@ISA $VERSION);

$VERSION = $IO::Tty::VERSION;

@ISA = qw(IO::Handle);

eval { require IO::Stty };
push @ISA, "IO::Stty" if (not $@);  # if IO::Stty is installed

sub new {
    my ($class) = $_[0] || "IO::Pty";
    $class = ref($class) if ref($class);
    @_ <= 1 or croak 'usage: new $class';

    my ($ptyfd, $ttyfd, $ttyname) = allocate_pty();

    croak "cannot open a pty" if not defined $ptyfd;

    my $pty = $class->SUPER::new_from_fd($ptyfd, "r+");
    $pty->autoflush(1);
    my $slave = $class->SUPER::new_from_fd($ttyfd, "r+");
    $slave->autoflush(1);
    ${*$pty}{'io_pty_slave'} = $slave;
    ${*$pty}{'io_pty_ttyname'} = $ttyname;

    bless $pty => $class;
}

sub slave {
    @_ == 1 or croak 'usage: $pty->slave();';

    my $master = shift;
    if (exists ${*$master}{'io_pty_slave'}) {
      return ${*$master}{'io_pty_slave'};
    }

    my $tty = ${*$master}{'io_pty_ttyname'};

    my $slave = new IO::Tty;

    $slave->open($tty, O_RDWR) ||
	croak "Cannot open slave $tty: $!";

    ${*$slave}{'io_pty_ttyname'} = $tty;
    ${*$master}{'io_pty_slave'} = $slave;
    $slave->autoflush(1);
    return $slave;
}

sub ttyname {
    my $pty = shift;
    ${*$pty}{'io_pty_ttyname'};
}

sub slave_pid {
    my $pty = shift;
    ${*$pty}{'io_pty_slave_pid'};
}

sub spawn {
  my ($self, @cmd) = @_;

  $self = $self->new
    unless $self and ref($self);

  # set up pipes to sync with child
  pipe(PARENT_RDR, CHILD_WTR) or die "Cannot open pipe: $!";
  pipe(CHILD_RDR, PARENT_WTR) or die "Cannot open pipe: $!";
  pipe(STAT_RDR, STAT_WTR) or die "Cannot open pipe: $!";
  CHILD_WTR->autoflush(1);
  PARENT_WTR->autoflush(1);
  STAT_WTR->autoflush(1);

  my $pid = fork;

  unless (defined ($pid)) {
    warn "Cannot fork: $!" if $^W;
    return undef;
  }

  if($pid) {
    # parent
    my $errno;
    ${*$self}{io_pty_slave_pid} = $pid;
    close PARENT_RDR; close PARENT_WTR; close STAT_WTR;

    # close slave if it has been opened via ->slave
    if (exists ${*$self}{'io_pty_slave'}) {
      close  ${*$self}{'io_pty_slave'};
      delete ${*$self}{'io_pty_slave'};
    }

    # wait for child to init slave pty
    my $errstatus = sysread(CHILD_RDR, $errno, 1);
    die "Cannot sync with child: $!" if not defined $errstatus;
    warn "Sync returned EOF" if not $errstatus and $^W;
    # let child go ahead with exec
    print CHILD_WTR "\n";
    close CHILD_RDR; close CHILD_WTR;

    # now wait for child exec (eof due to close-on-exit) or exec error
    $errstatus = sysread(STAT_RDR, $errno, 256);
    die "Cannot sync with child: $!" if not defined $errstatus;
    close STAT_RDR;
    if ($errstatus) {
      $! = $errno+0;
      warn "Cannot exec(@cmd): $!\n" if $^W;
      return undef;
    }
    return $self;
  }
  else {
    # child
    close CHILD_RDR; close CHILD_WTR; close STAT_RDR;

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

    # now open slave, this should set it as controlling tty on some systems
    my $ttyname = ${*$self}{'io_pty_ttyname'};
    my $slv = new IO::Tty;
    $slv->open($ttyname, O_RDWR)
      or croak "Cannot open slave $ttyname: $!";
    $slv->autoflush(1);

    # close slave if it has been opened via ->slave
    close(${*$self}{'io_pty_slave'}) if ${*$self}{'io_pty_slave'};

    # Acquire a controlling terminal if this doesn't happen automatically
    if (defined TIOCSCTTY) {
      if (not defined ioctl( $slv, TIOCSCTTY, 0 )) {
	warn "warning: TIOCSCTTY failed, child might not have a controlling terminal: $!" if $^W;
      }
    } elsif (defined TCSETCTTY) {
      if (not defined ioctl( $slv, TCSETCTTY, 0 )) {
	warn "warning: TCSETCTTY failed, child might not have a controlling terminal: $!" if $^W;
      }
    }

    {
      my $dummy;
      # tell parent we are done with init
      print PARENT_WTR "\n";
      # wait for parent to ack
      die "Cannot sync with parent: $!"
	if sysread(PARENT_RDR, $dummy, 1) != 1;
      close PARENT_RDR; close PARENT_WTR;
    }

    close($self);
    close(STDIN);
    open(STDIN,"<&". $slv->fileno())
      or die "Couldn't reopen STDIN for reading, $!\n";
    close(STDOUT);
    open(STDOUT,">&". $slv->fileno())
      or die "Couldn't reopen STDOUT for writing, $!\n";
    open(STDERR,">&". $slv->fileno())
      or die "Couldn't reopen STDERR for writing, $!\n";
    close($slv);

    { exec(@cmd) };
    print STAT_WTR $!+0;
    die "Cannot exec(@cmd): $!";
  }
}

1;

__END__

=head1 NAME

IO::Pty - Pseudo TTY object class

=head1 VERSION

0.92_03 beta

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

    # spawn a program
    $cmd = IO::Pty->spawn($command, @args)
      or die "Cannot spawn $command: $!\n";

    print $cmd "command\n";
    $response = <$cmd>;
    kill TERM => $cmd->slave_pid;


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

=item slave

The C<slave> method will return a new C<IO::Pty> object which
represents the slave side of the pseudo tty.  If IO::Stty is
installed, you can call $slave->stty() to modify the terminal
settings.

=item ttyname

Returns the name of the pseudo tty. On UNIX machines this will be
the pathname of the device.

=item spawn

Spawns the given command via exec() (see there for semantics) and
attaches its stdin/out/err to the slave side of the pty.  Returns the
master pty upon success or undef upon failure; $! will contain the
error of the failed exec().

spawn() autovivifies a pty if called without an object, i.e.

  spawn IO::Pty (@command);

or

  IO::Pty->spawn(@command);


=item slave_pid

Returns the PID of the spawned process (if any).

=back


=head1 SEE ALSO

L<IO::Tty>, L<IO::Handle>, L<Expect>


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

The spawn() code was modeled after its Tcl/Expect counterpart by Don
Libes <libes@nist.gov>.

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

