#
# TODO:
#  probably should export ioctl constants
#  pod
#

package IO::Tty;

use IO::Handle;
use IO::File;

require DynaLoader;

use vars qw(@ISA $VERSION);

$VERSION = "0.01";
@ISA = qw(IO::Handle DynaLoader);

bootstrap IO::Tty;

sub open
{
 my($tty,$dev,$mode) = @_;

 IO::File::open($tty,$dev,$mode) or
	return undef;

 InitSlave($tty,$dev);

 $tty->autoflush;

 1;
}

1;
