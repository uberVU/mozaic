Mozaic Widgets - the feuilleton novel
=====================================

What is a Widget?
-----------------

In Mozaic, a widget is the basic unit of encapsulating a reusable element
of display. Examples range from a fancy graph built using Highcharts to a
very basic number widget which displays a number and syncs it whenever it
changes.

Why approach such a small display element as a number with such a heavy
abstraction as a widget? Well, the answer is pretty simple: the number of
useful information you can concurrently display to a user that is actually
readable is not that large. Besides that, we're constantly optimizing Mozaic to
be able to smoothly run pages with hundreds of widgets.

What is the benefit of this approach? Very small number of synchronization
problems (since a widget as small as a number) is itself an active element of
the page.


What is the role of a Widget?
-----------------------------

A widget does two and only two things (with very small exceptions):

* respond to data events by updating the DOM. Here, a widget is the master of
its own DOM, and widget should not try to access the DOM of other widgets.
While at first sight this seems to be a severe limitation, in practice we have
managed to implement it with very few hacks

* respond to GUI events which are the result of the user interacting with the
Single Page App - scrolling, clicking, hovering over elements and so on

If widgets do only two things, how do they interact with one another? In most
cases, DOM interaction can be limited to the piece of DOM which is represented
by the widget. If a widget needs to interact with another widget, it means that
it has to trigger one of two types of events (as per the philosophy of a widget)

- a DOM event, to which the second widget should respond. This should never
happen, because DOM events are produced only by the user

- a data event. For this use-case, the widgets must share an interest in the
same data channel, with the first widget updating that channel (usually with
server-side implications as well), while the second widget reponds to the
change in data, without knowing where that change is coming from and why.

Also, it is our recommendation that widgets should be stateless (e.g. do not
store any state in themselves, possibly examine the DOM for getting state), and
that they do not hold references to the data passed to them by the data
callbacks. Holding those references makes it much harder to do garbage
collection automatically.

An Example
----------

```coffeescript

define ['cs!widget'], (Widget) ->

    class UserNameWidget extends Widget

        subscribed_channels: 'users/{{user_id}}'

        # This will be loaded automatically on @renderLayout() calls and
        # the dictionary passed to renderLayout will be passed to this template.
        # We're using the Handlebars templating language, but this can easily
        # be extended to other templating languages as well.
        template_name: 'templates/user_name.hjs'

        params_defaults:
            'user_id': 'data-params'

        params_required: ['user_id']

        get_users: (user_params) =>
            ###
                This callback is called automatically by the framework in order
                to handle the data events for the "users" channel. users is
                an internal alias, and what that channel actually represents
                is decided by the "parent" widget of this one.
            ###
            return unless user_params.type == 'change'

            @renderLayout({'name': user_params.model.get('name')})

```

params_defaults specifies the parameters that should have default values for
this widget. In this case, we're saying that user_id should be set to whatever
constructor parameter the widget receives and it represents the id of the user
we're displaying. This user is always found within a collection of one or more
users, hence the 'users/' prefix for the subscribed_channel.

params_required specifies that user_id is a required parameter for this widget,
and the framework will yield an error if we try to initialize it without it.

How a widget is created and initialized
---------------------------------------

How does a widget end up into the page? Well, the widget is injected into the
page with a wrapper DOM element like this:

<div class="mozaic-widget" data-widget="user_name"
     data-params="{user_id: 23, channels: {'/users': '/users-234'}}"/>

This element can be injected at any time in the DOM, via jQuery, DOM API or
your preferred method, and the framework will react to this by initializing the
widget, wiring it up to the DOM events, and sending data to it whenever data is
available. Notice the perspective that a widget cannot request data, but the
framework sends data to it whenever it is available.

There are several important elements in this injected widget:

- the mozaic-widget class, which is necessary for the framework to identify it
as a Mozaic widget. The dom element need not be div, it can be anything else,
as long as it bears this special CSS class

- the data-widget meta-parameter, which tells the framework which class of code
to load for this widget. This is found out only at runtime, and we're using
require.js in order to load that class when we need it. This allows us to break
the code into multiple bundles. The simplest way to use this is to have one
big bundle of code

- the data-params meta-parameter, which is a serialized JSON, and which are
the constructor parameters for the widget. Why is it important for these
parameters to fit into a JSON? Mozaic is opinionated and forces you to not
transmit references between widgets, which makes for cleaner code and easier
garbage collection.

After the framework detects that such a special DOM element has appeared
(this is done by WidgetStarter - by using Mutation events in the latest
browsers, and polling the DOM in older versions of browsers), it loads up its
code class, establishes its data dependencies (subscribed_channels), and
initializes the widget only when data has been fetched from the server for each
of its channels.

How the SPA DOM looks like and how it is rendered
-------------------------------------------------

Everything starts with a big widget called a controller. What's different
between this widget and all other widgets is that we determine what this widget
is based on the current URL fragment. So, if the current URL looks like:

http://your-single-page-app.com/index.html#users_page

Mozaic will take the users_page fragment, try to match it against a list of
known fragments and determines which widget should be injected (via jQuery)
for this fragment. The controller widget is injected, it waits for its data,
and whenever the data events it waits for are complete, it calls renderLayout()
causing a part of the DOM to be rendered. This part of the DOM usually contains
several mozaic-widget declarations in it, causing those widgets to be started,
and those widgets will do renderLayout() as well at a certain point.

This creates a tree of widgets that continuously react to data events, and
which inject other widgets when they perform a renderLayout(). Detecting when
this tree of widgets finishes loading is a tough problem in itself, because
we don't have an easy way to estimate how many of them will be when first
visiting the page (see loading_animation.coffee for more details).

What happens when you change the "page"? (a.k.a. controller)
------------------------------------------------------------

From a DOM standpoint, changing the controller means nothing else than emptying
the #controller-container div and injecting a new controller widget there.

The rest happens under the hood: Mozaic detects that there are widgets it
knows about but not in the DOM anymore, and it starts "garbage collecting" them.
At Mozaic-level, garbage collection means cutting off some references and
unbinding some events so that we make the browser GC's job easier.

This GC occurs in batches in order not to freeze the GUI. Therefore, since
on a page there can be a couple hundred of widgets, it can take up to a few
minutes for all widgets to disappear from Mozaic after changing the page.
Mozaic also GCs channels, when there is no more widget to reference them.

Aggregated channels
-------------------

Aggregated channels is a concept similar to promise joining (see
https://github.com/stackp/promisejs). A widget may wish to subscribe to
notifications from several channels at once, and only render its content when
all the channels have data in them.

An example of the widget that uses this:

```coffeescript

define ['cs!widget'], (Widget) ->

    class SumWidget extends Widget

        subscribed_channels: ['/number1', '/number2']
        aggregated_channels: {both_numbers: ['/number1', '/number2']}

        both_numbers: (number1_params, number2_params) ->
            return unless (number1_params.type == 'change' and
                           number2_params.type == 'change')

            sum = number1_params.model.get('number') +
                  number2_params.model.get('number')
            @renderLayout({'sum': sum})

```

This widget needs two channels to combine the data in them by displaying the
sum of the two numbers in the given channels. It cannot render the data without
data in both channels, so Mozaic has the concept of aggregated channels:
a callback of your choice gets called whenever data from all the channels
you specify is available.

What is most often mis-understood about this mechanism is when the callback is
fired:
* for the first time, it is fired after both /number1 and /number2 have some
  data in them (so there might be multiple events on a single channel before
  data comes in the second channel)
* afterwards, it will be called after __each__ change for /number1 OR /number2,
  which means that if both /number1 and /number2 change, it will be called 2
  times (since the changes cannot occur synchronously .. right? :)

Passing down channels and channel management
--------------------------------------------

Conceptually, when a widget describes which channels it's interested in via
subscribed_channels, it defines some pipes in which events can be pumped.
Whenever a parent widget injects this widget, it has to connect all these pipes
to something. They can filled with:

* its own pipes (so channels it has received itself from its parent widget which
are passed down to the child widget)
* newly created channels (pipes) by the parent widget.

Let me exemplify both situations:

```cofeescript

define['cs!widget'], (Widget) ->

    class Parent extends Widget

        subscribed_channels: ['/items_passed_down_to_child']
        template_name: 'parent.hjs'

        initialize: =>

            channel_params =
                '/items_created': {} # no params for this channel
            [created_channel_guid] = Utils.newDataChannels(channel_params)

            child_params=
                channels:
                    /items_passed_down_to_child: @channel_mapping['/items_passed_down_to_child']
                    /items_created: created_channel_guid

            @renderLayout(child_params)

    class Child extends Widget

        subscribed_channels: ['/items_passed_down_to_child', '/items_created']

```

and the template file is:

```html

<div class="mozaic-widget" data-widget="child" data-params="{{child_params}}"/>

```

In this case, the channel /items_passed_down_to_child is received by the Parent
widget from its own parent, and is passed down to the Child widget. The other
channel is created locally in this widget, and passed down.

Usually, Controllers are the widgets which create most channels, but there are
many exceptions in practice. Also, Mozaic has the notion of global channels,
which need not be passed down from widget to widget, because it would be too
much of a hassle (imagine passing down the same channel 13 levels of nesting
deep!).

State management & state managers
---------------------------------

Widgets also function like Finite State Machines around data availability.
They have an internal state that is triggered when their data is empty, or
when they are waiting for new data to be loaded. You can read more about
state management in state_management.md doc.

How are widgets implemented? High level overview
------------------------------------------------

First of all, in order to understand widgets, you should be familiar with
Backbone.JS (more specifically, Backbone.View, Backbone.Collection and
Backbone.Model). A widget is a subclass of Module, the base class for all
Mozaic components. The main role of Module is to automatically add try-catch
around each method for each such module, so that we isolate crashes of a
component and report them correctly using the exception logging mechanism.
Why is such crash isolation important? This mechanism, together with breaking
the code into multiple sequences via setTimeout(0) helps you breathe relieved
whenever a new intern joins your company and works on a widget - at its worst,
the intern will only break the widget he is working on :P

A widget has a Backbone.View attached to it (you can access it via @view from
widget code) that delegates events to the DOM of the widget. In addition to
that, it parses and validates whatever the widget receives in data-params as
parameters at initialization.

Widgets also emit events (messages) through the global Mozaic pubsub mechanism,
such as:
* /new_widget_rendered - the first time a widget has been rendered
* /widget_rendered - every time a widget has been rendered
* /new_widget_appeared - every time a widget has been initialized completely
                         (event caught by Datasource in order to bind it
                          to the correct channels/models, and by
                          loading_animation in order to know when the difference
                          rendered vs. appeared is becoming stable)

In addition to emitting events at important lifecycle moments, a widget
translates the parameters for data callbacks from the Backbone-native format
into dictionaries in order to make it more easy to have aggregated channels
callbacks.

Life cycle of a widget
----------------------

1. Widget is injected in the DOM via Utils.inject(), Utils.injectWidget()
   (deprecated) or renderLayout() from another widget. Here you can use any
   other method, but in practice these are the most used 3 methods.

2. Widget is picked up by widget starter via Mutation Observer / Mutation Events
   or even DOM polling (for those old browsers). Regardless of the case, an
   async event that a widget is in the DOM which is not managed by Mozaic
   is generated. Unless the widget has data-delayed=true which tells the
   Widget starter to "hold it until that attribute is not there anymore", it
   marks the widget as "processed" by adding a guid to it.
   (TODO: separate DOM observing from widget starter into a separate component)

3. Widget Starter adds the class "widget-#{widget_type}" to the widget for
   easier targeting from CSS, and translates some channels which are globally
   present in Mozaic apps (so called Global Channels, created by
   createGlobalChannel and retrieved by translateGlobalChannels). This makes
   sure that any widget receiving global channels doesn't know about it.

4. Widget Starter knows which channels from DataSource are initialized, and
   which aren't, via the /initialized_channel pubsub event, so it will either
   start the widget immediately if all of its channels from subscribed_channels
   are initialized, or put it in a queue that is checked after each such event.

   This section of the code is problematic because it cannot check for channels
   that are created in the initialize callback of the widget. This is a known
   limitation and we have been avoiding this kind of use-case in Mozaic when
   possible.

5. Widget Starter calls loader.loadWidget(), which uses require.js to fetch
   the code for the widget class, if it hasn't been fetched already. Whenever
   the code is fetched, the template is fetched afterwards and compiled (if
   necessary), and afterwards Utils.createModuleInstance is called which
   basically wraps the new Widget() statement into a try-catch in order to
   avoid problems in the constructor. The rest of the try-catch'es are handled
   by the Module class, the base class for everyone.

   NOTE: after this step, the widget will be available in loader.widgets[guid]

6. Widget constructor is ran via Utils.createModuleInstance(), which in turn
   parses parameters, creates the associated Backbone View, sets up aggregated
   channels and finally announces that the widget is initialized. A very
   important call in the widget constructor is to initialize(), the preferred
   method of executing something at widget init, and not by overriding the
   constructor. This is placed conveniently at the proper bootstrap point
   in the widget constructor.

7. DataSource catches the /new_widget event and basically binds the widget
   methods like get_number, auto-generated from channel names to their
   respective models and collections, using Backbone.Collection and
   Backbone.Model's on() and off() methods (which in turn are inherited from
   Backbone.events).

   One significant functionality of the DataSource at this point is that it
   performs a reset()-like event to send to the widget the existing data in
   the channel, if there was at least one successful fetch for that channel.

   This is why it's important to wait in Widget Starter for all the channels
   to be ready, in order to minimize the time between widget construction
   and widget rendering.

8. From this point on, the widget is on its own, and so are the channels.
   Datasource only receives requests related to the channels from widgets via
   pubsub, makes sure that it fetches data for the channels when it should,
   and channels/models publish events directly to the widgets. Widgets then
   translate these events from variable number of parameters to dictionaries
   and push it to their callbacks.

9. Widget interacts with user by using events delegated by the Backbone.View
   to the DOM of the widget. This ensures us that callbacks from the "events"
   key of the widget are ran in the context of the widget whenever the user
   interacts with the widget DOM. At this point, the widget can interact with
   the DataSource by using methods like @addChannel(), @removeChannel() and
   @modifyChannel() to send requests for modifying the collections/models
   in the DataSource via pubsub. DataSource then faithfully executes these
   requests (with optional server-side sync-ing) and then channels propagate
   these events to widgets directly.

10. At some point, the widget is taken out from the DOM. Again, WidgetStarter
    is notified via the best available mechanism (MutationObserver being the
    preferred one) and depending on the URGENT_FOR_GC flag which may or may be
    not available in the widget instance, it is put either in a priority GC
    queue (mediator widgets and controllers being the preferred examples),
    either in a normal priority queue.

11. Widget starts to be detached from DOM immediately, via startBeingDetached().
    At this point the widget instance still exists, because it's too expensive
    to GC them synchronously, but it is bound to a detached DOM, and @view is
    set to null in order to signal this.

12. Widget's destroy() method is called, channel methods are unbound, etc,
    thus allowing channels to be GC'ed later on as well. Finally, loader.widgets
    is cleaned up of the widget reference (which was there for debugging
    purposes anyway).

The connection between widgets and datasource
---------------------------------------------

Widgets have subscribed_channels, which can both be declared statically and
both be augmented in the widget initialize() method. e.g. some widgets in
their initialize() do @subscribed_channels.push(...).

DataSource does not know about aggregated channels, it only knows about some
data callbacks of widgets for the subscribed channels. The aggregated channels
mechanism is built on top of this, transparently by intercepting the data
callbacks and calling the aggregated callbacks whenever it's necessary.

DataSource keeps track of which widgets are subscribed to which channel (by
their id, not their reference) in order to know when the channel is becoming
a candidate for GC (when no widgets are referencing it).

DataSource acts like a middle-man between widgets and channels: it helps to
match-make them, and then it gets out of the way, letting the channels push
data by themselves to the widgets via Backbone.Events on(), off() and trigger().

DataSource further interacts with the widgets via pubsub events, whenever
they ask it to make modifications to channels and models on their behalf. The
trickiest flow here is adding a new model to a channel and thus POSTing it
to the server as well - DataSource creates a clone of that model, which isn't
in any collection at all, sends it to the server and receives the response, and
only on 201 created adds it to the collection itself. Same for modifying an
existing model.

Finally, DataSource offers a uniform interface for widgets to interact with
RawData type of channels (deeply unstructured JSONs) and stuff that's easily
modelled with Backbone.Collection and Backbone.Model.
