# NAME

KelpX::AppBuilder - Create re-usable apps with Kelp

# SYNOPSIS

KelpX::AppBuilder makes it trivial to reuse your entire route map and views in an entirely new Kelp application. You create a base app, which can still be run normally, and from there you can start a new project and reuse everything from your base app without duplicating things.

# USAGE

## Create a base application

This launches your main application, allowing you to attach other ones onto it

```perl
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
```

## Creating an app for your base

We'll call our new app 'TestApp' (original, eh?).
All your app really needs to provide is a function called `maps`. This should 
return a hash reference of your routes.
Don't forget to include the absolute path to your controllers (ie: Using the + symbol)

```perl
package TestApp;

use KelpX::AppBuilder;

sub maps {
    {
        '/testapp/welcome', '+TestApp::Controller::Root::welcome'
    }
}

1;
```

And that's all there is to it.

## Using templates from apps

One thing you're probably going to want to do is use something like Template::Toolkit to process 
your views in apps that aren't the base. Fortunately `KelpX::AppBuilder::Utils` will deploy 
`module_dir` from [File::ShareDir](https://metacpan.org/pod/File::ShareDir) for you, so in your controllers something like this could happen:

```perl
package TestApp::Controller::Root;

use KelpX::AppBuilder::Utils;

# create some way to access the view path globally
# so you don't have to keep writing it
sub view_path { module_dir('TestApp') . '/views/' }

sub index {
    my ($self) = @_;
    $self->template(view_path() . 'index.tt');
}
```

So now when the index method is called from TestApp, it'll search `lib/auto/TestApp/views` for its 
templates.

This is probably your best option for now, as KelpX::AppBuilder does not have a safe way to load app 
configuration just yet (working on it!).

## Automatically include stash when rendering template

One thing I hate doing is retyping the same thing over and over again, like adding the stash to the 
template for example

```perl
$self->template('file.tt', $self->stash);
```

So KelpX::AppBuilder now comes with a `detach` method, which works the exact same way as `template`, but 
will automatically add the stash items for you, so all you need to do is

```perl
$self->detach('file.tt');
```

It's a minor shortcut, but saved me quite a few key strokes already.

## Beginning URL building

What this means is KelpX::AppBuilder will automatically append the childs app name onto the beginning of the route url. As an example, you may have the following Kelp apps: `BaseApp` and `BaseApp::ChildApp`. Turning on URL building will append `/childapp` to the beginning of every URL in that module.

```perl
package BaseApp::ChildApp;

use KelpX::AppBuilder;

sub maps {
    {
        '/users', '+BaseApp::ChildApp::Controller::Users::list',
    }
}
```

Instead of the route being `/users` in the above example, it will actually become `/childapp/users`. As I'm writing a modular web app, I wanted each modules route to stay in their respective namespace, but I didn't want to type it out every time.
It will not do this by default, because not everyone will want it. If you want to add this feature, when you call `kelpx_appbuilder`, just pass it the baseapps package name as a parameter and it'll do the rest.

```perl
package BaseApp;

use KelpX::AppBuilder;

sub build {
    my ($self) = @_;
    my $routes = $self->routes;
    $routes->kelpx_addbuilder(__PACKAGE__)->add_maps(qw/BaseApp::ChildApp/);
}
```

And that's all you literally need to do! To make sure it's loaded them correctly, just run plackup with the environment variable `KELPX_APPBUILDER_DEBUG=1` and it will display the routes loaded via `add_maps`.

# PLEASE NOTE

This module is still a work in progress, so I would advise against using KelpX::AppBuilder in a production environment. I'm still looking at ways to make KelpX::AppBuilder more user friendly, but unfortunately reusing an application is not a simple process :-)

# AUTHOR

Brad Haywood <brad@geeksware.com>

# LICENSE

You may distribute this code under the same terms as Perl itself.
