# Creating a new URL route

First of all, a new route implies a new Controller*. But before creating the Controller, let's register the new path for the app router.

## 1. Registering the route

In `conf/urls.js` you need a new entry under the ` App.urls` hash. E.g.

```js
App.urls = {
  // ...
  'users/:user_id': {
    'controller': 'UserController',
    'layout': 'templates/users/page.hjs',
    'allowed_get_params': ['show_friends'],
  },
  // ...
};
```

It's as simple as it looks like, here's a valid path: `http://localhost:8000/#/users/13?show_friends=true`, where the resulting filters will be `{user_id: 13, show_friends: true}`

## 2. Creating the controller

\* A Controller is a Widget subclass designed for being loaded at root level --- the first widget in a page, has no parent

A visible difference between a Controller and a regular Widget is that Controllers don't have their template path defined inside its class definition, but inside the App.urls entry. This is a page layout and is visible within the urls configuration.

Registering a Controller is no way different from registering a Widget, inside `conf/modules.js`:

```js
App.the_modules = {
  // ...
  'widget/UserController': 'modules/users/users_controller.coffee'
  // ...
};
```

Our convention is to use CamelCase for controller widget aliases.

To complete this tutorial, here's an example of a Controller subclass

```coffee
define ['cs!controller'], (Controller) ->
  class UsersController extends Controller
    ###
      Always describe the role of a Class
    ###
    subscribed_channels: ['/filters']
    
    get_filters: (filters) =>
      # A common trick for only allowing a whitelist of filters within
      # the context of this controller
      filters = filter_params.model.toJSON()
      allowed_filters = ['user_id', 'show_friends']
      url = Utils.render_url(@config.url, _.pick(filters, allowed_filters))
```
