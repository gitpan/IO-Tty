use ExtUtils::MakeMaker;

use Config;

my @define;

push(@define, '-DHAVE_DEV_PTC')
	 if (-e "/dev/ptc");

$pdir = (-d "/dev/ptym") ? "/dev/ptym" : "/dev";
@ptys = <$pdir/pty??>;
if (@ptys)
 {
  my %p0 = ();
  my %p1 = ();
  foreach (@ptys)
   {
    my ($x,$y) = /(.)(.)$/;
    $p0{$x}++;
    $p1{$y}++;
   }
  push(@define, '-DPTYRANGE0=\\"' . join('',sort(keys %p0)) . '\\"');
  push(@define, '-DPTYRANGE1=\\"' . join('',sort(keys %p1)) . '\\"');

  push(@define, '-DPTYTEMPLATE=\\"' . "$pdir/ptyXY" . '\\"');
 }

system('Configure') unless -f "config.h"; 
system($^X,'-pi','-e','s/_config_h_/_TTYconfig_h_/','config.h');

WriteMakefile(
    'NAME'	    => 'IO::Tty',
    'VERSION_FROM'  => "Tty.pm",
    'DEFINE'	    => join(" ", @define), 
    'dist'	    => { SUFFIX => 'gz', COMPRESS => 'gzip -f' },
    'clean'	    => {'FILES' => '*% *.html *.b[ac]k *.old *.orig *.rej a.out *log'},
    'MAP_TARGET'    => 'perltty'
);

