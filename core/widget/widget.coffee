define [
    'cs!mozaic_module'
    'cs!core/widget/aggregated_channels'
    'cs!core/widget/backbone_events'
    'cs!core/widget/channels'
    'cs!core/widget/params'
    'cs!core/widget/rendering'
    'cs!core/widget/states'
], (
    Module,
    WidgetAggregatedChannelsMixin,
    WidgetBackboneEventsMixin,
    WidgetChannelsMixin,
    WidgetParamsMixin,
    WidgetRenderingMixin,
    WidgetStatesMixin
) ->

    class Widget extends Module
        ###
            The widget is the building block of UIs in mozaic.js ie. interfaces
            are built by composing widgets that encapsulate functionality.

            The following is a centralized list of the properties supported
            by the widget class and their use-cases:

            @property {String} @template_name - path to widget's template, it's
                                    relative to the root of the application.
            @property {Object} @template - internal instance of a Handlebars
                                    object with compiled templates.
            @property {Number} @constructed_at - unix timestamp for the date
                                         when the widget constructor was run.

            @property {Object} @params - hash of parameters passed by parent
                                         widget upon injection into the DOM.
            @property {Object} @params_defaults - Specifies default values for
                    the widget @params. The format is `{key:value}`.
                    All specified keys are attached to the instance.
                    If `value` is a function then @key gets it's return value.
                        Note that these functions get executed in the context
                        of the widget after all other defaults have been set,
                        including the values set in @params, this means you can
                        modify the received value dynamically.
                    If `value` is `data-params` then @key gets the value from
                        the passed @params[key] object.
                    Otherwise, @key receives whatever `value` is passed in @params
            @property {Object} @params_required - an array of parameters
                                expected in @params from the injector widget.

            @property {Object} @elements - a hash `{'name':'selector'}`
                    This hash is processed after widget renders and sets
                    `@['name']` to be a jQuery element inside the widget
                    that matches `'selector'`
            @property {Object} @events - a hash with the following signature:
                    `{'event @element': 'functionName'} or
                    `{'event selector': 'functionName'}
                    It maps an `event` on a previously computed `@element` or
                    on every element that matches the `selector`, to a
                    `functionName` of the current object that acts as a
                    handler of that event.
                    NOTE! You might want to bind the handler function to the
                    current instance, otherwise the application.

            CHANNELS
            @property {Array} @subscribed_channels - list of channel types the
                                    widget is bound to. Whenever events are
                                    published on one of the channels defined
                                    here, a method named @get_<channel_name>()
                                    gets executed. Child widgets must implement
                                    these methods in order to get updates from
                                    the channel.
            @property {Object} @aggregated_channels - a list of channel types
                                    bound to a method name which allows the
                                    widget to access data from multiple channels
                                    at once.
            @property {Object} @aggregator - internal, holds data from the
                                    latest events of all channels the widget is
                                    bound to.
            @property {Array} @loading_channels -list of channels types whose
                                    aggregated events determine the widget's
                                    transition to a certain new state
            @property {Object} @channel_mapping - this is an internal hash that
                                    maps channel types from @subscribed_channels
                                    to the actual instances of the channel.
            @property {Boolean} @URGENT_FOR_GC

            STATES
            @property {String} @initial_state - internal, holds the name of the
                                initial state. NOTE that this is called 'init'.
            @property {Array} @loadingStates - internal, holds a list of states
                                for all aggregated channels. The possible states
                                supported by a channel are 'init', 'empty',
                                'incompatible', 'available'.
                                @see WidgetStatesMixin#changeState
            @property {String} @data_state -
            @property {Boolean} @STRICT_CHANGE_STATE

            RENDERING
            @property {Object} @view - instance of Backbone.View
            @property {Object} @el - intance of jQuery, @deprecated
            @property {Boolean} @isDetachedFromDOM - flag indicating if the
                                    widget is not in the DOM anymore.
            @property {Object} @saved_view - instance of Backbone.View, relevant
                                    for detached widgets, ie. widgets that are
                                    no longer in the DOM.
            @property {Object} @saved_el - instance of jQuery, again only
                                    relevant for detached widgets.
            @property {Object} @pre_render - hash of context processors to be
                                    executed _before_ the widget is rendered.
                                    A context processor is a function that
                                    modifies the behaviour or presentation of
                                    the widget in some way.
                                    NOTE that context processors need to be
                                    registered globally in
                                    ubvu_application_controller before usage.
            @property {Object} @post_render - hash of context processors with
                                    their parameters to be executed after the
                                    widget has rendered. Examples: tooltip,
                                    tinyscrollbar.
            @property {Object} @layout - instance of core/layout class.

            @property {Boolean} @rendered_signal_sent - flag sent right after
                                    publishing `/new_widget_rendered`.
        ###

        ###
            /new_widget_rendered can be sent only once per widget instance.
            It is sent in one of two cases:

            1) if the widget has no template_name, it most probably means
               that it's a proxy widget, so it will send this signal on
               initialize. loading_animation will then keep waiting after
               its children. If it has no children, it must be an utility
               widget, so either way it doesn't make sens to wait for it
               to render.

            2) if the widget has a template_name, it will send a signal
               on the first un-silenced renderLayout. Most (99%) of renderLayout
               calls are un-silenced, but sometimes we want to make sure when
               the page finishes loading, we see a certain content (aka the
               full content), while when we navigate from page to page it's
               acceptable to see smaller loading animations.
        ###
        rendered_signal_sent: false

        ###
            Initial state of the widget. It is toggled by default when
            the widget starts.

            Set it to any of the supported states to start the widget
            in a particular state.

            Override the default state using the data-param _initial_state_
            property.

            @see #changeState
        ###
        initial_state: null

        # Set this to true to only trigger changeState() whenever there is
        # a transition from an old state to a different new state (a transition
        # is also triggered if the old state and new state are both 'available')
        STRICT_CHANGE_STATE: false

        constructor: (params, template = null) ->
            # Call super module's self-wrapping constructor
            super()

            ###
                Every time a new widget is instatiated, publish a request to `new_widget`
                In this request, also send the channels the widget will be subscribed to
            ###

            @constructed_at = Utils.now() / 1000
            if template
                @template = template
            if params.template_name?
                @template_name = params.template_name
            @params = params
            @channel_mapping = params.channels or {}

            @_initParamsDefaults()
            @_checkForRequiredParams()
            if not @subscribed_channels
                @subscribed_channels = []

            @_parseDomEvents()

            # View initialization must come first, before announceNewWidget method call
            # This is because announceNewWidget might cause the widgets' render
            # method to be called if data is already available in the datasource
            # for the given keys.
            @_initializeBackboneView()

            # Precompile in Handlebars widget's template must come before announceNewWidget
            if @template
                @template = Handlebars.compile(@template)

            # Widget initialization must happen as early as possible in the cycle
            # of instantiating the widget. This is because some widgets define
            # their subscribed_channels / aggregated_channels dynamically in
            # their initialize() method.
            @initialize()

            # Perform a sanity check that this widget has all the data it needs
            if not @_checkChannels(@subscribed_channels, @channel_mapping)
                logger.error "Trying to initialize widget #{@params['name']} without the required channels from controller"
                return

            # Setup the aggregated channels, which allow a widget to respond
            # with a single function on the events for one or more channels.
            # For example, a widget might choose to react to any change in
            # /mentions' OR '/tags' with the same function (because the stuff
            # to draw depends on both types of data).
            @setupAggregatedChannels()

            # The initial state can be received as an argument through
            # _params_defaults_. If this is the case, overwrite the
            # @initial_state instance variable with that one.
            @_triggerInitialState()

            # Make sure that the widgets' event handlers receive nice dicts
            # with lots of info about the event that took place on the collection.
            # We do this by wrapping the existing functions in others that
            # translate the parameters from Backbone.Collections format to ours.
            @_setupEventParamsTranslation()

            # Hook to events from child widgets
            @_setupChildEvents()

            # Publish to the datasource that there is a new widget which
            # is interested in certain data channels
            @announceNewWidget()

        announceNewWidget: ->
            ###
                Announce that a new widget has been instantiated.

                This will cause the datasource to perform match-making between
                the widget's interests and the available datasources.
            ###
            message = {
                name: @params['name']
                widget: @
                subscribed_channels: @_getTranslatedSubscribedChannels()
            }

            pipe = loader.get_module('pubsub')

            # Announce the creation of the widget first, and once all callbacks
            # of /new_widget have been called, announce a new event that makes
            # the widget ready for business, such as reciving data for channels
            pipe.publish('/new_widget /widget_ready', message)

            # If this widget doesn't have a template, it either:
            # a) doesn't have any visible representation
            # or
            # b) spawns other widgets, and those will wait for the data
            #
            # So it's a sane choice to announce immediately that it has rendered.
            if not @template_name
                pipe.publish('/new_widget_rendered', @params['widget_id'], @params['name'])
                @rendered_signal_sent = true

        _initializeBackboneView: ->
            ###
                Initialize the widget associated Backbone.View.
            ###
            # Setting a view at start will only be done if a dom element
            # is sent along with the contructor params
            #
            # This is always done by the widget starter.
            if @params.el
                @setView(new Backbone.View(el: @params.el))
                # Propagate "urgent for GC" flag to view class
                if @URGENT_FOR_GC
                    @view.$el.addClass('urgent_for_gc')

        _triggerInitialState: ->
            ###
                Triggers the initial state of the widget, if there is one.
            ###
            if @params.initial_state?
                @initial_state = @params.initial_state
            # Only trigger initial state if one is specified
            if @initial_state?
                # Setup state management workflow only if the @loading_channels is a
                # populated Array, otherwise the state management defaults to disabled.
                if _.isArray(@loading_channels) and not _.isEmpty(@loading_channels)
                    # Create aggregated event handlers based on the loading channels,
                    # that change the state of the widget based on their type and order
                    @setupLoadingChannels()
                # Trigger initial data state
                @changeState(@initial_state)

        _setupChildEvents: ->
            ###
                Hook to events from child widgets. We're currently only
                listening to render events from child widgets, but more could
                be implemented in the future.

                TODO: Big refactoring, make all widgets run around a
                pubsub channel of their own and have this sort of widget events
                run on their respecive channel only, with the option to bubble
                up to parent widgets up to the top widgets of the app
            ###
            # Only add an event listener if a handler function
            # for it appears to be defined
            return unless typeof(@onChildRender) is 'function'
            # Save handler method reference so it can be removed from pubsub
            # when trying to GC widget
            @_onChildRender = Utils.onWidgetRender(null, this, @onChildRender)

        initialize: ->

        render: ->

        destroy: =>
            now = Utils.now() / 1000
            # If widget has only lived half a second, something is wrong
            # and somebody is wasting widgets for nothing.
            if now - @constructed_at < 0.5
                cloned_params = _.clone(@params)
                delete cloned_params['el']
                logger.warn("Widget with id #{@params['widget_id']} has lived too little (less than half a second). You're doing something wrong. (params = #{JSON.stringify(cloned_params)})")

            if @saved_view
                #undelegate events
                @saved_view?.off?()
                #unbind element
                @saved_view?.unbind?()
                #remove element
                @saved_view?.remove?()

            pipe = loader.get_module('pubsub')
            pipe.publish('/destroy_widget', {
                name: @params['name']
                widget: this})

            # Remove the on child render event listener, if previously set
            # TODO: There should be a more elegant way to handle more events
            # of this type and unsubscribing them all at once through some
            # sort of system (rather than addressing them individually)
            if _.isFunction(@_onChildRender)
                pipe.unsubscribe('/new_widget_rendered', @_onChildRender)

        startBeingDetached: =>
            ###
                Mark the fact that the widget is currently detached from DOM.
            ###
            @isDetachedFromDOM = true

            # Make sure that detached widgets trying to access the DOM fail.
            @saved_view = @view
            @view = null
            @saved_el = @el
            @el = null

    Widget.includeMixin(WidgetAggregatedChannelsMixin)
    Widget.includeMixin(WidgetBackboneEventsMixin)
    Widget.includeMixin(WidgetChannelsMixin)
    Widget.includeMixin(WidgetParamsMixin)
    Widget.includeMixin(WidgetRenderingMixin)
    Widget.includeMixin(WidgetStatesMixin)
