package KelpX::AppBuilder::Object;

sub new {
    my ($self, $routes, $args) = @_;
    $args //= {};

    my $obj = bless {
        routes => $routes,
        from   => $args->{from}||undef,
        acl    => $args->{acl}||undef,
    }, 'KelpX::AppBuilder::Object';

    if ($args and ref $args->{from}) {
        $args->{from}->{builder} = $obj;
    }

    return $obj;
}

sub apps {
    my ($self, @apps) = @_;
    my $routes = $self->{routes};
    for (@apps) {
        KelpX::AppBuilder->new($_)->add_maps($routes, {
            from => $self->{from}||undef,
            acl  => $self->{acl}||undef,
        });
    } 
}

sub acl {
    my ($self, $params) = @_;
    $self->{acl} = $params;
    return $self;
}

1;
__END__
