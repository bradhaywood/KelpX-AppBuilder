package KelpX::AppBuilder;

use 5.010;
use warnings;
use strict;
use Module::Find 'useall';

our $VERSION = '0.002';

=head1 NAME

KelpX::AppBuilder - Create re-usable apps with Kelp

=head1 SYNOPSIS

KelpX::AppBuilder makes it trivial to reuse your entire route map and views in an entirely new Kelp application. You create a base app, which can still be run normally, and from there you can start a new project and reuse everything from your base app without duplicating things.

=head1 USAGE

First off, we'll need to modify the structure so File::ShareDir knows where to find our views/assets globally. It should look something like this

  BaseApp/lib/auto/BaseApp/views
  BaseApp/lib/auto/BaseApp/assets

You don't have to use the same names, just the structure.

Then, in your base application

  package BaseApp;
  
  use Kelp::Base 'Kelp';
  use KelpX::AppBuilder 'Base';

  # we don't need a build method, KelpX::AppBuilder will automatically
  # create it based on what we define in the maps method
  sub maps {
      {
          '/' => BaseApp::Controller::Root->can('index'),
          '/login' => BaseApp::Controller::Auth->can('login'),
          '/accounts/manage/:id' => {
              to      => BaseApp::Controller::Accounts->can('manage'),
              bridge  => 1
          },
          '/accounts/manage/:id/view', BaseApp::Controller::Accounts->can('view'), 
      }
  }

  1;

B<Optionally> you can include an 'auto' method into your application. The auto method gets called before every single page, so it's handy to use to ensure a user is logged in. You can do this by adding 
  'auto' => 1

to your maps hash ref. It will handle the route line and bridging for you. Don't forget to create the auto method in BaseApp::Controller::Root if you enable this though! An example:

  package BaseApp::Controller::Root;

  sub auto {
      my ($self) = @_;
      my $url    = $self->named->{page};
      unless ($url eq 'login') {
          if (my $user = $self->user) {
            return 1;
          }

          return;
      }

      return 1;
  }

We'll call our new app 'TestApp' (original, eh?). Copy across your config from BaseApp into your TestApp conf, then use File::ShareDir so your Template::Toolkit knows where to find the views for both applications.

  my $path = File::ShareDir::module_dir( 'BaseApp' );
  middleware_init => {
        Static => {
            path => qw{^/assets/|^/apps/},
            root => $path,
        },
      
        ...
  },

  # use local views, and the one from BaseApp
  'Template::Toolkit' => {
      ENCODING => 'utf8',
      INCLUDE_PATH => [
        './views',
        $path . '/views'
      ],
      RELATIVE => 1,
      TAG_STYLE => 'asp',
  },

The final part is loading your BaseApp controllers into your TestApp. That's fairly easy.

  package TestApp;

  use Kelp::Base 'Kelp';
  use KelpX::AppBuilder;

  sub build {
      my ($self) = @_;
      my $r = $self->routes;
      
      KelpX::AppBuilder->new('BaseApp')->add_maps($r);

      # now you can add TestApp's own routing
      $r->add('/hello', sub { "Hello, world!" });
  }

  1;

Congratulations. You've just reused the controllers from your BaseApp.

=cut

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

=head1 PLEASE NOTE

This module is still a work in progress, so I would advise against using KelpX::AppBuilder in a production environment. I'm still looking at ways to make KelpX::AppBuilder more user friendly, but unfortunately reusing an application is not a simple process :-)

=head1 AUTHOR

Brad Haywood <brad@perlpowered.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
1;
__END__
