define ['cs!channels_utils'], (channels_utils) ->

    class WidgetAggregatedChannelsMixin
        ###
            This class contains all aggregated-channels
            related functionality of the Mozaic widget.
        ###

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


        replaceTokensWithParams: (str) ->
            ###
                Replaces tokens of the form {{id}} from the string with values from params.

                The params are received from the HTML when the widget is instantiated.
                TODO: change this to a more pleasant syntax, maybe ruby-like (:id)
            ###
            for k,v of @params
                if str.indexOf('{{' + k + '}}') != -1
                    str = str.replace(new RegExp('{{' + k + '}}', 'g'), v)
            str

        setupAggregatedChannels: ->
            ###
                Sets up the aggregated channels.
            ###
            aggregated_channels = @_getAggregatedChannels()
            for aggregate_function of aggregated_channels
                if not (aggregate_function of @)
                    logger.warn("Aggregate function #{aggregate_function} does not exist")
                    continue
                channels = aggregated_channels[aggregate_function]
                # Wrap callback in order to make sure that the we're always
                # calling the current method for a given key on the widget,
                # since members of a class instance can be overridden
                # dynamically at any point in JavaScript
                @aggregateChannels((=> this[aggregate_function](arguments...)),
                                   channels)

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
            key = _.reduce(channels, (x,y) -> x + '+' + y)
            @aggregator[key] = {}

            # Generate channel callbacks or wrap the existing ones
            channel_callbacks = {}
            for channel in channels
                channel_key = channels_utils.getChannelKey(channel)
                channel_callbacks[channel] = channels_utils.widgetMethodForChannel(channel_key)

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
