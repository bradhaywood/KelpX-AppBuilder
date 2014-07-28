use 5.006;
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;

name     'KelpX-AppBuilder';
all_from 'lib/KelpX/AppBuilder.pm';
author   q{Brad Haywood <brad@perlpowered.com>};
license  'artistic2';

perl_version 5.006;

tests_recursive('t');

resources (
   #homepage   => 'http://yourwebsitehere.com',
   #IRC        => 'irc://irc.perl.org/#KelpX-AppBuilder',
   license    => 'http://www.perlfoundation.org/artistic_license_2_0',
   #repository => 'git://github.com/Brad Haywood/KelpX-AppBuilder.git',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=KelpX-AppBuilder',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
    'File::ShareDir' => 0,
    'Module::Find' => 0,
);

install_as_cpan;
auto_install;
WriteAll;
