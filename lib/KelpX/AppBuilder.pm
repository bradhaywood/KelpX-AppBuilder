package KelpX::AppBuilder;

use 5.010;
use warnings;
use strict;
use KelpX::AppBuilder::Object;
use Module::Find 'useall';
use File::ShareDir 'module_dir';

our $VERSION = '0.004';

sub import {
    my ($me, @opts) = @_;
    my $class = caller;
    {
        no strict 'refs';
        eval "use Kelp::Routes";
        *{"Kelp::Routes::kelpx_appbuilder"} = sub { KelpX::AppBuilder::Object->new(shift); };
    }
    if (@opts and $opts[0] eq 'Base') {

        my @controllers = useall "${class}::Controller";
        {
            no strict 'refs';
            for my $c (@controllers) {
                eval "use $c" unless scalar keys %{"${c}::"};
                say "=> Loaded controller $c";
            }
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

    if (@opts and $opts[0] eq 'Config') {
        if (scalar @opts > 1) {
            my $mod = $opts[1];
            {
                no strict 'refs';
                eval "use $mod" unless scalar keys %{"${mod}::"};
            }
            if ($@) {
                die "[error] Could not load base module $mod into config: $@\n";
            }

            {
                no strict 'refs';
                my $hsh;
                my $con  = "${mod}::Config";
                eval "use $con";
                if ($@) { die "(!) Could not load config module '$con': $@"; $hsh = {}; }
                $hsh  = $con->config();
                *{"${class}::base_path"} = sub { return module_dir($mod) };
                *{"${class}::base_config"} = sub { return $hsh; };
            }

        }
        else {
            die "[error] Config import option expects a base app name\n";
        }
    }

    if (@opts and $opts[0] eq 'BaseConfig') {
        if (scalar @opts > 1) {
            my $mod = $opts[1];
            {
                no strict 'refs';
                eval "use $mod";
                if ($@) { die "[error] Could not load base mod: ${mod}\n"; }
    
                *{"${class}::base_path"} = sub { return module_dir($mod); };
            }
        }
        else {
            die "[error] BaseConfig import option expects base app name\n";
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

=head1 NAME

KelpX::AppBuilder - Create re-usable apps with Kelp

=head1 SYNOPSIS

KelpX::AppBuilder makes it trivial to reuse your entire route map and views in an entirely new Kelp application. You create a base app, which can still be run normally, and from there you can start a new project and reuse everything from your base app without duplicating things.

=head1 USAGE

=head2 Create a base application

This launches your main application, allowing you to attach other ones onto it

  package BaseApp;
  
  use Kelp::Base 'Kelp';
  use KelpX::AppBuilder;

  sub build {
      my ($self) = @_;
      my $routes = $self->routes;

      # The only thing we need to do is tell KelpX::AppBuilder what
      # apps we want to load. Their routes will be added onto BaseApps.

      $r->kelpx_appbuilder->apps(
          'TestApp',
          'TestApp2'
      );

      # Then load the main ones as normal

      $r->add('/' => BaseApp::Controller::Root->can('index'));
      $r->add('/login' => BaseApp::Controller::Auth->can('login'));
      $r->add('/accounts/manage/:id' => {
          to      => BaseApp::Controller::Accounts->can('manage'),
          bridge  => 1
      });
      $r->add('/accounts/manage/:id/view', BaseApp::Controller::Accounts->can('view'));
  }

  1;

=head2 Creating an app for your base

We'll call our new app 'TestApp' (original, eh?).
All your app really needs to provide is a function called C<maps>. This should 
return a hash reference of your routes.
Don't forget to include the absolute path to your controllers (ie: Using the + symbol)

  package TestApp;

  use Kelp::Base 'Kelp';
  use KelpX::AppBuilder;

  sub maps {
      {
          '/testapp/welcome', '+TestApp::Controller::Root::welcome'
      }
  }

  1;

And that's all there is to it.

=head1 SHARING CONFIG BETWEEN BASEAPP AND ITS CHILDREN

You can share config from your base application so you don't have to rewrite stuff you want 
to reuse. In your child applications C<conf/config.pl>, just add

  use KelpX::AppBuilder Config => 'BaseApp';
  return base_config();

This will load everything from C<BaseApp::Config::config()>. So let's create that.

  package BaseApp::Config;

  sub config {
      return {
          modules      => [qw/Template JSON Logger/],
          modules_init => {

              # One log for errors and one for debug
              Logger => {
                  outputs => [
                      [
                          'File',
                          name      => 'debug',
                          filename  => 'log/debug.log',
                          min_level => 'debug',
                          mode      => '>>',
                          newline   => 1,
                          binmode   => ":encoding(UTF-8)"
                      ], [
                          'File',
                          name      => 'error',
                          filename  => 'log/error.log',
                          min_level => 'error',
                          mode      => '>>',
                          newline   => 1,
                          binmode   => ":encoding(UTF-8)"
                      ],
                  ]
              },

              # JSON prints pretty
              JSON => {
                  pretty => 1
              },

              # Enable UTF-8 in Template
              Template => {
                  encoding => 'utf8'
              }
          }
      };
  }

=head1 PLEASE NOTE

This module is still a work in progress, so I would advise against using KelpX::AppBuilder in a production environment. I'm still looking at ways to make KelpX::AppBuilder more user friendly, but unfortunately reusing an application is not a simple process :-)

=head1 AUTHOR

Brad Haywood <brad@geeksware.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
1;
