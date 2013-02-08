define ['cs!channels_utils', 'cs!widget'], (channels_utils, Widget) ->
    class MediatorWidget extends Widget
        ###
            The Mediator Widget listens for events on the input channels and
            triggeres events on the datasource that refresh the output channels.
            These events can be /refresh, /scroll, etc.
            The data from all input channels is merged together into a single object
            and pushed as params to all output channels, thus triggering a new
            data fetch from the server.

            Warning! The mediator should not be used to modify data channels directly.
            That's datasource's job. It's only purpose is to translate changes from
            input channels into changes on output channels.

            The MediatorWidget has 4 main parameters:
            - input_channel: it listens to events on this datasource channel
            - output_channels: the datasource channels to give as a parameter
                when an event on input_channel happens
            - message: the message to send to the datasource
                (can be '/refresh', '/scroll', etc., anything
                that receivs a list of channels as a parameter).
                Default value: 'refresh'.

            The Mediator widget also supports a list of ignored attributes for
            the input channels, which changed alone shouldn't trigger any
            changes on the output channels. The ignored attributes are also
            removed from the output channel params when other (not ignored)
            attributes trigger publishing.
        ###

        # This widget has priority when it comes to garbage collection
        URGENT_FOR_GC: true

        params_defaults:
            'message': '/refresh'
            'input_channel': 'data-params'
            'input_channels': 'data-params'
            'output_channel': 'data-params'
            'output_channels': 'data-params'
            'skip_first': 'data-params'
            'ignored_attributes': (attrs) -> attrs or []

        initialize: =>
            # HORRIBLE HACK (see https://github.com/bogdans83/ubvu-unleashed/issues/1190)
            # By default skip_first = true because most mediators have
            # filters as their input channels, which results in an extra
            # API call due to a datasource bug :)
            # TODO(andrei): remove this once DS bug gets fixed
            if not @skip_first?
               @skip_first = true

            if @input_channel?
                @input_channels = [@input_channel]
            if @output_channel?
                @output_channels = [@output_channel]
            @first = true

            # Subscribe to the input channels
            @subscribed_channels = @input_channels
            @aggregated_channels = {get_input_channels: @subscribed_channels}

            @pipe = loader.get_module('pubsub')

        get_input_channels: (params...) =>
            ###
                get_input_channels is an aggregated channels callback that gets triggered
                on every event of the input channels. It collects data from all
                events an pushes it to the data channel, which in turn refreshed the
                output channels.

                skip_first skips the first aggregated event for this
                set of channels. It is useful in order to avoid spurious events
                like the case of filters being initialized either before
                or after this widget in the Datasource.

                TODO(andrei): find a better solution
            ###
            if @first
                @first = false
                if @skip_first
                    return

            # Decide whether to continue with publishing on the output channels
            # if other attributes than the ignored ones have been changed
            eventIsRelevant = false
            for channel_params in params
                changedAttributes = _.keys(channel_params.model.changed)
                changedAttributes = _.without(changedAttributes,
                                              @ignored_attributes...)
                eventIsRelevant = true if changedAttributes.length

            @publishToChannel(params) if eventIsRelevant

        publishToChannel: (params, options = {}) =>
            ###
                This method publishes an event of type @message
                Allow the option to skipStreampollBuffer when publishing refresh to channel
                @param {Array} params - array of channel parameters (like initial data)
                    that get merged together then published on the output channel.
                @param {Object} [options] - options passed to Pubsub#publish
                @param {Boolean} [options.skipStreampollBuffer]
            ###
            skipStreampollBuffer = if options.skipStreampollBuffer? then options.skipStreampollBuffer else false

            # Merge data input channels data into a single object.
            translated_channel_params = {}
            for channel_params in params
                _.extend(translated_channel_params, @translateParams(channel_params))

            for channel in @output_channels
                translated_output_channel = @channel_mapping[channel]
                channel_message = {}
                channel_message[translated_output_channel] = translated_channel_params
                # Notify each channel in output channels
                # with @message event
                @pipe.publish(@message, channel_message, { skipStreampollBuffer: skipStreampollBuffer })

        translateParams: (params) ->
            ###
                Translates parameters from the input_channel format
                to the format accepted by the output channel.

                Override this in your mediator class to pass whatever parameters
                you like to the output channel.

                @params {String} [params.type] - type of the channel event
                        @see Widget#_translateEventParams() for details on possible values.
                @params {Object} [params.model] - instance of BaseModel, is passed for events
                        on channels that are backed by a single model. Ex: /streams/{{id}}
                @params {Object} [params.collection] - instance of BaseCollection backing the channel.
            ###
            return _.omit(params.model.toJSON(), @ignored_attributes)

    return MediatorWidget
