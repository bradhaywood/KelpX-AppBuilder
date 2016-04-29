package KelpX::AppBuilder;

use 5.010;
use warnings;
use strict;
use KelpX::AppBuilder::Object;
use Module::Find 'useall';
use File::ShareDir 'module_dir';
use Import::Into;
use Kelp::Base;

our $VERSION = '0.005';

sub import {
    my ($me, @opts) = @_;
    my $class = caller;
    {
        no strict 'refs';
        eval "use Kelp::Routes";
        Kelp::Base->import::into($class, 'Kelp');
        *{"Kelp::Routes::kelpx_appbuilder"} = sub { KelpX::AppBuilder::Object->new(shift, shift); };
        *{"${class}::detach"} = sub {
            my ($shelf, $file) = @_;
            $shelf->template($file, $shelf->stash);
        };
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
                my $classpath = $class;
                $classpath =~ s/Oboo:://g;
                $classpath    =~ s/::/-/g;
                $classpath = lc "/${classpath}";
                for my $method (keys %$maps) {
                    $method = "${classpath}${method}";
                    #TODO: Check for array ref (ie: ["POST" => url]

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
    my ($self, $r, $from) = @_;
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
        if ($from) {
            my $classpath = $mod;
            my $origclass = $from; 
            $classpath =~ s/${origclass}:://g;
            $classpath    =~ s/::/-/g;
            $classpath = lc "/${classpath}";
            foreach my $path (keys %$maps) {
                my $abspath = "${classpath}${path}";
                if ($path eq 'auto') {
                    my $root = "${mod}::Controller::Root";
                    $r->add('(.+)' => { to => $root->can('auto'), bridge => 1 });
                    next;
                }

                say "-> Adding route: $abspath" if $ENV{KELPX_APPBUILDER_DEBUG};
                $r->add($abspath, $maps->{$path});
            }
        }
        else {
             foreach my $path (keys %$maps) {
                if ($path eq 'auto') {
                    my $root = "${mod}::Controller::Root";
                    $r->add('(.+)' => { to => $root->can('auto'), bridge => 1 });
                    next;
                }

                say "-> Adding route: $path" if $ENV{KELPX_APPBUILDER_DEBUG};
                $r->add($path, $maps->{$path});
            }
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

  use KelpX::AppBuilder;

  sub maps {
      {
          '/testapp/welcome', '+TestApp::Controller::Root::welcome'
      }
  }

  1;

And that's all there is to it.

=head2 Using templates from apps

One thing you're probably going to want to do is use something like Template::Toolkit to process 
your views in apps that aren't the base. Fortunately C<KelpX::AppBuilder::Utils> will deploy 
C<module_dir> from L<File::ShareDir> for you, so in your controllers something like this could happen:

  package TestApp::Controller::Root;

  use KelpX::AppBuilder::Utils;

  # create some way to access the view path globally
  # so you don't have to keep writing it
  sub view_path { module_dir('TestApp') . '/views/' }

  sub index {
      my ($self) = @_;
      $self->template(view_path() . 'index.tt');
  }

So now when the index method is called from TestApp, it'll search C<lib/auto/TestApp/views> for its 
templates.

This is probably your best option for now, as KelpX::AppBuilder does not have a safe way to load app 
configuration just yet (working on it!).

=head2 Automatically include stash when rendering template

One thing I hate doing is retyping the same thing over and over again, like adding the stash to the 
template for example
  
  $self->template('file.tt', $self->stash);

So KelpX::AppBuilder now comes with a C<detach> method, which works the exact same way as C<template>, but 
will automatically add the stash items for you, so all you need to do is

  $self->detach('file.tt');

It's a minor shortcut, but saved me quite a few key strokes already.

=head2 Beginning URL building

What this means is KelpX::AppBuilder will automatically append the childs app name onto the beginning of the route url. As an example, you may have the following Kelp apps: C<BaseApp> and C<BaseApp::ChildApp>. Turning on URL building will append C</childapp> to the beginning of every URL in that module.

  package BaseApp::ChildApp;

  use KelpX::AppBuilder;

  sub maps {
      {
          '/users', '+BaseApp::ChildApp::Controller::Users::list',
      }
  }

Instead of the route being C</users> in the above example, it will actually become C</childapp/users>. As I'm writing a modular web app, I wanted each modules route to stay in their respective namespace, but I didn't want to type it out every time.
It will not do this by default, because not everyone will want it. If you want to add this feature, when you call C<kelpx_appbuilder>, just pass it the baseapps package name as a parameter and it'll do the rest.

  package BaseApp;

  use KelpX::AppBuilder;

  sub build {
      my ($self) = @_;
      my $routes = $self->routes;
      $routes->kelpx_addbuilder(__PACKAGE__)->add_maps(qw/BaseApp::ChildApp/);
  }

And that's all you literally need to do! To make sure it's loaded them correctly, just run plackup with the environment variable C<KELPX_APPBUILDER_DEBUG=1> and it will display the routes loaded via C<add_maps>.

=head1 PLEASE NOTE

This module is still a work in progress, so I would advise against using KelpX::AppBuilder in a production environment. I'm still looking at ways to make KelpX::AppBuilder more user friendly, but unfortunately reusing an application is not a simple process :-)

=head1 AUTHOR

Brad Haywood <brad@geeksware.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
1;
