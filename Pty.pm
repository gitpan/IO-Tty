# pod at end
# Based on original Ptty package by Nick Ing-Simmons

package IO::Pty;

use Carp;
use IO::Tty;
use IO::File;

use vars qw(@ISA $VERSION);

$VERSION = "0.01";

@ISA = qw(IO::Handle);

sub new
{
 my $class = $_[0] || "IO::Pty";
 @_ == 1 or croak 'usage: new $class';

 my $pty = $class->SUPER::new;
 my $tty;
 my $fd = OpenPTY($tty);

 $pty->fdopen($fd, "r+");

 $pty->autoflush;

 ${*$pty}{'io_pty_ttyname'} = $tty;

 $pty;
}

sub slave
{
 @_ == 1 or croak 'usage: $pty->slave();';

 my $pty = shift;
 my $tty = ${*$pty}{'io_pty_ttyname'};

 my $slave = new IO::Tty;

 $slave->open($tty, O_RDWR) ||
	croak "Cannot open $dev as $tty:$!";

 return $slave;
}

sub ttyname
{
 my $pty = shift;
 ${*$pty}{'io_pty_ttyname'};
}

1;

__END__

=head1 NAME

IO::Pty - Pseudo TTY object class

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

=head1 CONSTRUCTOR

=over 3

=item new

The C<new> contructor take no arguments and returns a new object which
the master side of the pseudo tty.

=back

=head1 METHODS

=over 3

=item slave

The C<slave> method will return a new C<IO::Pty> object which
represents the slave side of the pseudo tty

=item ttyname

Returns the name of the pseudo tty. On UNIX machines this will be
the pathname of the device.

=back

=head1 SEE ALSO

L<IO::Handle>

=head1 AUTHOR

Graham Barr E<lt>F<gbarr@ti.com>E<gt>

Based on original Ptty module by Nick Ing-Simmons
E<lt>F<nik@tiuk.ti.com>E<gt>

=head1 COPYRIGHT

Most of the C code used in the XS file is covered by the GNU GENERAL
PUBLIC LICENSE, See COPYING

All other code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
