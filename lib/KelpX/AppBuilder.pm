package KelpX::AppBuilder;

use 5.010;
use warnings;
use strict;
use Module::Find 'useall';

our $VERSION = '0.001';

sub import {
    my ($me, @opts) = @_;
    my $class = caller;
    if (@opts and $opts[0] eq 'Base') {
        my @controllers = useall "${class}::Controller";
        for my $c (@controllers) {
            eval "use $c";
            say "=> Loaded controller $c";
        }

        {
            no strict 'refs';
            *{"${class}::build"} = sub {
                my ($self) = @_;
                my $r    = $self->routes;

                my $maps = $class->maps;
                for my $method (keys %$maps) {
                    $r->add($method, $maps->{$method});
                }
            };
        }
    }
}

sub new {
    my ($class, $base) = @_;
    my $self = { name => $base };
    eval "use $base";
    if ($@) {
        print STDERR "[error] Failed to open $base: $@\n";
        exit 5;
    }

    my @controllers = useall "${base}::Controller";
    eval "use $_"
        for @controllers;


    return bless $self, $class;
}

sub load_controllers {
    my ($self, @controllers) = @_;
    for my $c (@controllers) {
        eval "use $self->{name}::Controller::$c";
        if ($@) {
            die "[error] Could not load controller $c: $@\n";
        }
    }

    return $self;
}

sub add_maps {
    my ($self, $r) = @_;
    {
        my $class = caller;
        no strict 'refs';

        my $mod = $self->{name};
        unless ($mod->can('maps')) {
            print STDERR "Base mod $mod is missing 'maps' method\n";
            exit 3;
        }

        my @no_import = qw(new build import);
        foreach my $method (keys %{"${mod}::"}) {
            *{"${class}::${method}"} = *{"${mod}::${method}"}
                unless grep { $_ eq $method } @no_import;
        }
        my $maps = $mod->maps;
        foreach my $path (keys %$maps) {
            if ($path eq 'auto') {
                my $root = "${mod}::Controller::Root";
                $r->add('/:page' => { to => $root->can('auto'), bridge => 1 });
                next;
            }

            $r->add($path, $maps->{$path});
        }

    }
}

1;
__END__
