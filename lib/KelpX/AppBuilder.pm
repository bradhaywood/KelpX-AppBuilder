package KelpX::AppBuilder;

use 5.010;
use warnings;
use strict;

sub new {
    my ($class, $base) = @_;
    my $self = { name => $base };
    eval "use $base";
    if ($@) {
        print STDERR "[error] Failed to open $base: $!\n";
        exit 5;
    }

    return bless $self, $class;
}

sub load_controllers {
    my ($self, @controllers) = @_;
    for my $c (@controllers) {
        eval "use $self->{name}::Controller::$c";
        if ($@) {
            die "[error] Could not load controller $c: $!\n";
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
            $r->add($path, $maps->{$path});
        }

    }
}

1;
__END__
