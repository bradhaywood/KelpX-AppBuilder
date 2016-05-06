package KelpX::AppBuilder::Routes;

use Moo::Role;
use Scalar::Util 'blessed';
requires 'add_maps';

sub add_route {
	my ($self, $ctx, $r, $url, $target) = @_;
	if (ref $target and ref $target eq 'HASH') {
		if ($target->{acl} and blessed $ctx) {
			$ctx->{route_maps} //= [];
			if ($ctx->can('session')) {
				{
					no strict 'refs';
					no warnings 'redefine';
					my $to = $target->{to};
					if (substr $to, 1 eq '+') {
						$to =~ s/^.//;
						push @{$ctx->{route_maps}}, $to;
						my $coderef = \&{$to};
						*{$to} = sub {
							if ($ctx->session and $ctx->session->{user}) {
								unless ($ctx->session->{user}->has_permission($to)) {
									$ctx->res->render_error(401);
									return;
								}
							}

							$coderef->(@_);
						};
					}
				}
			}
		}
	}

	$r->add($url, $target);
}

1;