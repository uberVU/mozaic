List Widgets
============

Abstract
--------

This document describes how to use the `list_widget` correctly.

How it works
------------

The Mozaic core contains a [list widget](https://github.com/uberVU/mozaic/blob/master/core/base_widgets/list.coffee)
It takes an `/items` channel and an item widget and renders a list of widgets,
one for each element in the `/items` channels. It has the ability to pass
aditional params to the individual item widget, it supports pagination, sorting,
dinamic add/remove of elements on `/items` channel and thus is intended to be
used `as is`, without extending it.

See the [class docs for more details](https://github.com/uberVU/mozaic/blob/master/core/base_widgets/list.coffee)
and supported behaviour

Example steps to inject a simple list widget
--------------------------------------------

Say we want to inject a list of users in the page from an application controller.
Suppose we have a `/users` channel already instantiated in the controller.

1. Before injecting a list widget, you must provide a widget to be rendered for
each element in the list. This can be any widget rigged to listen to a generic
`/items` channel, which in this case it's the `/users` channel.

````coffee
# user_item.coffee
class UserItemWidget extends Widget

    subscribed_channels: ['/users/{{id}}']

    # Define a template for displaying the user data.
    template_name: 'teamplates/user_item.hjs'

    get_users: (params) ->
        # We will only re-render the widget once the data has changed, either
        # completely (`reset`) or partially (`change`). Ignore other events.
        return unless params.type in ['reset', 'change']

        # Serialize the model data received with the event and render the widget.
        params = params.model.toJSON()
        @renderLayout params
````

_Notice_ that the channel this widget is subscribed to is called `/users/{{id}}`.
This is because the list widget splits the input `/users`Y collection channel
into multiple model channels, one for each model in the collection. It then passes
each of these model channels to a new instance of the `UserItemWidget`. In this way each
widget renders a different user model from the list and whenever a user record changes only
it's widget will get re-rendered and not the entire list.

2. buildup the injection params. At the very minimum you must supply the `/items` channel
and the `item` string param which holds the name of the widget to be injected for
each model in the collection. Below is an exceprt from the controller's method the injects
the users list.

````coffeescript
params =
    users_list_params:
        channels:
            '/items': @channel_mapping['/users']
        item: 'user_item'

@renderLayout params, false
````

The template for the controller contains this section:

````html
<div class="mozaic-widget" data-widget="list" data-params="{{user_list_params}}"></div>
````
_Note_ that we pass in the `/users` channel translated as `/items`. This is possible
in mozaic and required by the list widget. It only knows how to list a channel if
that channel is called `/items`. Also note that the `/users` channel was already
created and stored in the controller's channel mappings. You can create a channel
using [Utils.newDataChannels]()

The `item` param is the module name of the widget. Read more on module name in the
docs for [require.js](http://requirejs.org/docs/api.html#define) a js lib used
extensively in mozaic. Suffice to say that `user_item` corresponds to the widget
defined in step 1 which was declared in your app's `conf/modules.js`.

3. That's it! ;)
