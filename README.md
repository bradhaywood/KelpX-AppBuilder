# NAME

KelpX::AppBuilder - Create re-usable apps with Kelp

# SYNOPSIS

KelpX::AppBuilder makes it trivial to reuse your entire route map and views in an entirely new Kelp application. You create a base app, which can still be run normally, and from there you can start a new project and reuse everything from your base app without duplicating things.

# USAGE

## Create a base application

This launches your main application, allowing you to attach other ones onto it

```perl
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
```

## Creating an app for your base

We'll call our new app 'TestApp' (original, eh?).
All your app really needs to provide is a function called `maps`. This should 
return a hash reference of your routes.
Don't forget to include the absolute path to your controllers (ie: Using the + symbol)

```perl
package TestApp;

use Kelp::Base 'Kelp';
use KelpX::AppBuilder;

sub maps {
    {
        '/testapp/welcome', '+TestApp::Controller::Root::welcome'
    }
}

1;
```

And that's all there is to it.

# SHARING CONFIG BETWEEN BASEAPP AND ITS CHILDREN

You can share config from your base application so you don't have to rewrite stuff you want 
to reuse. In your child applications `conf/config.pl`, just add

```perl
use KelpX::AppBuilder Config => 'BaseApp';
return base_config();
```

This will load everything from `BaseApp::Config::config()`. So let's create that.

```perl
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
```

# PLEASE NOTE

This module is still a work in progress, so I would advise against using KelpX::AppBuilder in a production environment. I'm still looking at ways to make KelpX::AppBuilder more user friendly, but unfortunately reusing an application is not a simple process :-)

# AUTHOR

Brad Haywood <brad@geeksware.com>

# LICENSE

You may distribute this code under the same terms as Perl itself.
