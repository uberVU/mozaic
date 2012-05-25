define ['cs!channels_utils', 'cs!module', 'cs!layout'], (channels_utils, Module, Layout) ->
    class Widget extends Module
        never_rendered: true

        constructor: (params, template = null) ->
            if not ('skip_fake_events' of @)
                @.skip_fake_events = false

            ###
                Every time a new widget is instatiated, publish a request to `new_widget`
                In this request, also send the channels the widget will be subscribed to
            ###
            if template
                @template = template
            if params.template_name
                @template_name = params.template_name
            @params = params
            @channel_mapping = params.channels
            @el = params['el']
            @_initParamsDefaults()
            @_checkForRequiredParams()
            if not @subscribed_channels
                @subscribed_channels = []

            # create a local variable 'events_callback' which has references to all events callbacks
            # also extend the backbone view constructor object with this newly created 'events_callbacks'
            events_callbacks = {}
            for key, fn of @events
                events_callbacks[fn] = @[fn]

            # view initialization must come first, before announceNewWidget method call
            #
            # This is because announceNewWidget might cause the widgets' render
            # method to be called if data is already available in the datasource
            # for the given keys.
            @view = new (Backbone.View.extend(_.extend({el: @el, events: @events}, events_callbacks)))

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

            # Make sure that the widgets' event handlers receive nice dicts
            # with lots of info about the event that took place on the collection.
            # We do this by wrapping the existing functions in others that
            # translate the parameters from Backbone.Collections format to ours.
            @_setupEventParamsTranslation()

            # Publish to the datasource that there is a new widget which
            # is interested in certain data channels
            @announceNewWidget()

        _initParamsDefaults: ->
            ###
                Initialize widget params default values.
            ###
            # If there is nothing to initialize, just return.
            if not ('params_defaults' of @)
                return

            # First pass is for non-function values
            for k, v of @params_defaults
                # If "this" already has k, it needs no default value
                if k of @
                    continue
                # First pass skips function values to give a more complete
                # view of "this" on the second pass to these functions
                if $.isFunction(v)
                    continue
                if v == 'data-params'
                    if k of @params
                        @[k] = @params[k]
                else
                    @[k] = v

            # Second pass will also run the functions
            for k, v of @params_defaults
                # If "this" already has k, it needs no default value
                if k of @
                    continue
                # This time we execute only functions
                if $.isFunction(v)
                    @[k] = v.apply(@)

        _checkForRequiredParams: ->
            ###
                Checks that the widget has all necessary required params.
            ###

            # If there is nothing to check, bail out.
            if not ('params_required' of @)
                return

            for p in @params_required
                if not p of @
                    logger.error("Widget #{params['widget_id']} is missing required parameter #{p}")

        _checkChannels: (subscribed_channels, channel_mapping) ->
            ###
                Make a sanity check to see if the constructors receives all the needed
                channels.
                Basically, every item in subscribed_channel list must have a reference
                in channels list.
                The order in which channels are defined should not matter
                eg. :
                      subscribed_channels = ['/mentions', '/tags']
                      channel_mapping = ['/mentions': '/mentions/guid1',
                                         '/tags': '/tags/guid2']
                      return true
            ###
            for subscribed_channel in subscribed_channels
                if not (channels_utils.getChannelKey(subscribed_channel) of channel_mapping)
                    logger.error("Widget #{@params['name']} with id #{@params['id']} is missing #{subscribed_channel}")
                    logger.error("Channel mapping: " + JSON.stringify(channel_mapping))
                    return false

            return true

        _getSubscribedChannels: ->
            ###
                Gets the data channels to which this widget is subscribed.

                This performs token replacement in channels data with parameters
                received at the widget initialization. For example, if widget
                has been initialized with id = 123 in its parameters, and there
                is a data channel "mention/{{id}}", this will return "mention/123".
            ###
            (@replaceTokensWithParams(channel) for channel in @subscribed_channels)

        _getTranslatedSubscribedChannels: ->
            new_channels = channels_utils.translateChannels(@subscribed_channels, @channel_mapping)
            result = {}
            for k, v of new_channels
                replaced_k = @replaceTokensWithParams(k)
                replaced_v = @replaceTokensWithParams(v)
                result[replaced_k] = replaced_v
            result

        _getAggregatedChannels: ->
            ###
                Gets the aggregated data channels to which this widget is subscribed.

                For more info, see the comments for _getSubscribedChannels.
            ###
            result = {}
            for aggregate_function of @aggregated_channels
                channels = @aggregated_channels[aggregate_function]
                result[aggregate_function] = (@replaceTokensWithParams(channel) for channel in channels)
            result

        _translateEventParams: (item_type, event_type, params...) ->
            ###
                Translates event parameters from a list to a map given the event type.
            ###
            if item_type == 'collection'
                if event_type == 'add'
                    return {type: 'add', model: params[0], collection: params[1]}
                else if event_type == 'remove'
                    return {type: 'remove', model: params[0], collection: params[1]}
                else if event_type == 'reset'
                    return {type: 'reset', collection: params[0]}
                else if event_type == 'destroy'
                    return {type: 'destroy', model: params[0], collection: params[1]}
                else if event_type == 'sync'
                    return {type: 'sync', model: params[0], collection: params[1]}
                else if event_type == 'error'
                    return {type: 'error', model: params[0], collection: params[1], response: params[2]}
                else if event_type == 'change'
                    return {type: 'change', model: params[0]}
                else if event_type[0..6] == 'change:'
                    return {type: 'change_attribute', attribute: event_type[7..], model: params[0]}
            else if item_type == 'item'
                if event_type == 'all'
                    return {type: 'change', model: params[0]}
                else if event_type == 'change'
                    return {type: 'change', model: params[0]}
                else if event_type[0..6] == 'change:'
                    return {type: 'change_attribute', attribute: event_type[7..], model: params[0]}
                else if event_type == 'error'
                    return {type: 'error', model: params[0], response: params[1]}
                else if event_type == 'sync'
                    return {type: 'sync', model: params[0], response: params[1]}
                

        _setupEventParamsTranslation: ->
            ###
                Sets up event parameter translation from backbone.js format to our own.

                This is done by creating a new function for each event.
            ###

            overwritten_functions = {}
            for channel in @_getSubscribedChannels()
                [collection, item, events] = channels_utils.splitChannel(channel)
                collection = channels_utils.getChannelKey(channel)
                do(channel, collection, item, events) =>
                    # Get which method of the widget is responsible for events
                    # of this data channel.
                    method = channels_utils.widgetMethodForChannel(@, collection)

                    # Don't overwrite the same function twice (for example, render)
                    if not (method of overwritten_functions)
                        overwritten_functions[method] = true
                        old_fn = @[method]
                        if old_fn
                            # If user is subscribing to a collection's events
                            if item == 'all'
                                # All events of a collection => first param of the function is the event type
                                if events == 'all'
                                    @[method] = (event_type, params...) =>
                                        translated_params = @_translateEventParams('collection', event_type, params...)
                                        old_fn(translated_params)
                                # A specific event of a collection => event type is taken from channel
                                else
                                    @[method] = (params...) =>
                                        translated_params = @_translateEventParams('collection', events, params...)
                                        old_fn(translated_params)
                            # A specific item of a given collection
                            else
                                # All events of an item of a collection
                                if events == 'all'
                                    @[method] = (event_type, params...) =>
                                        translated_params = @_translateEventParams('item', event_type, params...)
                                        old_fn(translated_params)
                                # A set of events of an item of a collection
                                else
                                    @[method] = (params...) =>
                                        translated_params = @_translateEventParams('item', events, params...)
                                        old_fn(translated_params)

        replaceTokensWithParams: (str) ->
            ###
                Replaces tokens of the form {{id}} from the string with values from params.

                The params are received from the HTML when the widget is instantiated.
                TODO: change this to a more pleasant syntax, maybe ruby-like (:id)
            ###
            compiled_str = Handlebars.compile(str)
            compiled_str(@params)

        setupAggregatedChannels: ->
            ###
                Setus up the aggregated channels.
            ###
            aggregated_channels = @_getAggregatedChannels()
            for aggregate_function of aggregated_channels
                if not (aggregate_function of @)
                    logger.warn("Aggregate function #{aggregate_function} does not exist")
                    continue
                channels = aggregated_channels[aggregate_function]
                @aggregateChannels(@[aggregate_function], channels)

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
            pipe.publish('/new_widget', message)

            # If this widget doesn't have a template, it either:
            # a) doesn't have any visible representation
            # or
            # b) spawns other widgets, and those will wait for the data
            #
            # So it's a sane choice to announce immediately that it has rendered.
            if not @template_name
                pipe.publish('/new_widget_rendered', @params['widget_id'])

        refreshChannel: (channel, params = null, already_translated = false) ->
            ###
                Shortcut for refreshing a single channel.
                See refreshChannels for more info.
            ###
            if not params
                @refreshChannels([channel], already_translated)
            else
                dict = {}
                dict[channel] = params
                @refreshChannels(dict, already_translated)

        refreshChannels: (channels, already_translated = false) ->
            ###
                Request a refresh of certain data channels to which this widget is subscribed.

                The method of the widget corresponding to the channel will be called
                back whenever the data is available.
            ###

            # We want to refresh an array of channels without any parameters at all
            if $.isArray(channels)
                if already_translated
                    translated_channels = channels
                else
                    translated_channels = [@channel_mapping[channel] for channel in channels]
                pipe = loader.get_module('pubsub')
                pipe.publish('/refresh', translated_channels)
            # We want to refresh a dict with keys = channels and values = params for refresh
            else if $.isPlainObject(channels)
                if already_translated
                    translated_channels = channels
                else
                    translated_channels = {}
                    for k, v of channels
                        translated_channels[@channel_mapping[k]] = v
                pipe = loader.get_module('pubsub')
                pipe.publish('/refresh', translated_channels)

        modifyChannel: (channel, dict, update_mode = 'append', already_translated = false) ->
            ###
                Request a modification of a certain data channel.
                If new_value is true, the sent value is the new value
                of the parameters for the data channel (e.g., internal
                parameters are reset).

                update_mode = 'append' appends the parameters to existing ones
                                        (possibly overwriting them)
                update_mode = 'reset' makes these the actual parameters
                                        (and updates the old values)
                update_mode = 'exclude' excludes these parameters
                                        (deletes them from the current parameters)

                How to use this:
                @modifyChannel('/mention/123', {title: 'new title'})
                @modifyChannel('/mentions_count', {count: 123})
            ###

            # Translate the channel using the channel mapping received
            # from the controller.

            if not already_translated
                translated_channel = channels_utils.translateChannel(channel, @channel_mapping)
            else
                translated_channel = channel

            # Replace tokens in the translated channel with tokens from params
            # This will allow us to post modifications to stuff like /mention/{{id}}
            replaced_channel = @replaceTokensWithParams(translated_channel)

            # HACK: send the update mode together with the params.
            dict['__update_mode__'] = update_mode
            pipe = loader.get_module('pubsub')
            pipe.publish('/modify', replaced_channel, dict)

        addChannel: (channel, dict) ->
            ###
                Adds a new model to the collection represented by the channel name
            ###

            # Translate the channel using the channel mapping received
            # from the controller.
            translated_channel = channels_utils.translateChannel(channel, @channel_mapping)
            message = {
                widget: @
            }

            pipe = loader.get_module('pubsub')
            pipe.publish('/add', translated_channel, dict, message)

        aggregateChannels: (callback, channels) ->
            ###
                Triggers callback whenever all channels have data

                This is similar to Promise.all() from the Promise.js framework.
                For example, if we wish the "render" method to be called whenever
                both "/mentions/123" and "/tags" data have arrived, we would use it
                like this:

                aggregateChannels(@render, ['/mentions/123', '/tags'])

                This call will trigger the 'render' member function whenever there
                is data for both the given mention and tags. THIS CREATES THE EVENT
                HANDLERS FOR EACH CHANNEL IF THEY DON'T EXIST, OR WRAPS THE EXISTING
                ONES OTHERWISE.

                After the first time data is available for all channels, this will
                trigger the callback each time there is data on any of the channels.

                Since this waits for *all* channels to get data, the following
                situations might happen:
                    - data for one of the channels never comes, and this
                        never gets executed
                    - data for a channel comes multiple times (for example,
                        the mention might be updated multiple times while waiting
                        for the tags to arrive). In this case, the callback
                        gets as parameters the last set of parameters for each
                        of the channels callbacks
            ###

            # Check if the aggregator data structure is in place.
            # If not, initialize it.
            if not @aggregator
                @aggregator = {}

            # Initialize the aggregator
            key = channels.reduce((x,y) -> x + '+' + y)
            @aggregator[key] = {}

            # Generate channel callbacks or wrap the existing ones
            channel_callbacks = {}
            for channel in channels
                channel_key = channels_utils.getChannelKey(channel)
                channel_callbacks[channel] = channels_utils.widgetMethodForChannel(@, channel_key)

            for channel, channel_callback of channel_callbacks
                do(channel_callbacks, channel, channel_callback, key) =>
                    # If the callback already exists, we will wrap it
                    # (similar to what decorators do in python).
                    # Otherwise, we will generate automatically a channel callback
                    # and set its property auto_generated to true
                    # (so that we don't break match-making from datasource)
                    old_fn = @[channel_callback] if channel_callback of @

                    new_fn = (params...) =>
                        # Run the old, wrapped function, if there is one
                        if old_fn
                            old_fn(params...)

                        # Aggregate the parameters passed to this function together
                        # with other sets of parameters
                        @aggregator[key][channel] = params

                        # aggregate_without_join tells us not to wait to have data from
                        # all the channels. Instead, wait to have data from at least
                        # ONE of the channels.
                        if @aggregate_without_join
                            callback_params = []
                            for c in channels
                                # Check if we have events from channel c
                                # If we do, we will push the data from those
                                # events. Otherwise, we will push "null".
                                if c of @aggregator[key]
                                    elem = @aggregator[key][c]
                                else
                                    elem = null
                                callback_params = callback_params.concat(elem)
                            # Signal the actual callback
                            callback(callback_params...)
                        # If we have received data from all channels,
                        # just signal the designated callback
                        else if _.keys(@aggregator[key]).length == _.keys(channel_callbacks).length
                            # Construct the list of parameters
                            callback_params = []
                            for c in channels
                                callback_params = callback_params.concat(@aggregator[key][c])
                            # Signal the actual callback
                            callback(callback_params...)

                    # Set the auto_generated flag to prevent breakage of the
                    # match-making algorithm in datasource
                    if not (channel_callback of @)
                        new_fn.auto_generated = true

                    # Replace the old existing function or create a new one
                    @[channel_callback] = new_fn

        initialize: ->

        render: ->

        destroy: ->
            @el.remove()

        renderLayout: (layout_params = {}, stringify = true) =>
            @layout = new Layout(@template_name, layout_params)
            @layout.renderHTML(@view.$el, stringify)
            if @never_rendered
                @never_rendered = false
                pipe = loader.get_module('pubsub')
                pipe.publish('/new_widget_rendered', @params['widget_id'])