uberVU, the leader of online social media monitoring, makes its own Coffee :)

This is our very own, home-brewed SPA framework. More details:
https://github.com/uberVU/mozaic/raw/master/mozaic.pdf

## Release notes for v0.3:
* released our latest Mozaic core internal version. Starting with this version, we will be eating our own dogfood and using Mozaic core from this repo. More details to follow.

## Release notes for v0.2:
* improved widget starter which now uses DOM Mutation events in order to detect when new widgets are added / removed
* forms support (read the comments!)
* datasource now supports "streampoll", a type of smart poll for a data channel which represents a stream; use-cases are twitter-like feeds where new items appear all the time
* support for automatic inclusion of files in index.html (actually this is a precursor to bundling, but our script just didn't make it in this release)
* loading animation by default
* support for adding new items to collections and deleting items from collections in Datasource
* almost complete isolation of widget crashes (automatic wrapping of all instance methods and new Module() calls)
* garbage collection! Widgets which disappear from the DOM will be killed and the data channels referenced by them also

In this repo you have a TODO list app called TodoVU following the model from [1].

[1]: http://addyosmani.github.com/todomvc/

# How to use Mozaic
This section is still under development...

## Creating a module
Register a module for `require.js` that can later be imported inside a different module, using the key is it defined under as its alias

In `conf/modules.js`
```js
App.the_modules = {
    // Alias -> actual path in project
    'model/user': 'modules/model/user',
    'collection/user': 'modules/collection/user',
    'widget/Dashboard': 'modules/controller/dashboard',
    'widget/Users': 'modules/controller/users',
    'widget/users': 'modules/widget/users'
};
```

## Creating a widget
See _Creating a module_ above for adding the widget file as a module

Basic widget class
```coffee
# Require the base widget as a dependency
define ['cs!widget'], (Widget) ->

    class UsersWidget extends Widget
        subscribed_channels: ['/users']
        template_name: 'templates/users.hjs'

        get_users: (params) =>
            ###
                Listener for changes on the /users data channel
            ###
            # Render layout whenever a "reset" event occurs and the entire
            # users collection is refreshed
            if params.type is 'reset'
                # Send entire collection to template and make sure it doesn't
                # get stringified in the process by setting the 2nd parameter
                # to false (inefficient example)
                @renderLayout(users: params.collection.toJSON(), false)
```

Basic widget template
```hjs
<ul>
    {{#each users}}
        <li>{{name}}</li>
    {{/each}}
</ul>
```

## Creating a controller
A controller is a widget that can be mapped to a url route. Contrary to the base widget encapsulation, a controller's template is defined in the `urls.js` config file, inside the route entry

In `conf/urls.js`
```js
App.urls = {
    // Default route (no hashbang or empty one)
    '': {
        'controller': 'Dashboard',
        'layout': 'templates/controller/dashboard.hjs'
    },
    'users': {
        'controller': 'Users',
        'layout': 'templates/controller/users.hjs'
    }
};
```
_As a convention, controllers are the only capitalized modules_

## Creating a data channel

In `conf/datasource.js`
```js
App.DataSourceConfig = {
  channel_types: {
    '/users': {
      type: 'relational',
      collection: 'users',
      url: '/api/users?format=json'
    }
  }
};
```
_The channel key should always start with a slash `/`_

### Channel options
* __type__ _required_
 * `relational` - Uses a collection of models to collect received data, used for list of items of the same type (most cases)
 * `api` - Uses a `RawData` object to collect received data, used for endpoints with fixed fields on a single object
* __collection__ _required_ - The alias name of the collection to be used, as defined in `conf/modules.js`, be it either a `BaseCollection` or a `RawData` subclass
* __url__ - The URL from which data is pulled and pushed upon (`GET`, `POST`, `PUT` and `DELETE`); it can be omitted if the channel data is meant to be both created and consumed on the client only
