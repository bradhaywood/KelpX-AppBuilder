package KelpX::AppBuilder::Object;

sub new {
    my ($self, $routes, $from) = @_;
    return bless {
        routes => $routes,
        from   => $from,
    }, 'KelpX::AppBuilder::Object';
}

sub apps {
    my ($self, @apps) = @_;
    my $routes = $self->{routes};
    for (@apps) {
        KelpX::AppBuilder->new($_)->add_maps($routes, $self->{from}||undef);
    } 
}

1;
__END__
