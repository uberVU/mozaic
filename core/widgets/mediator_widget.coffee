###
    The MediatorWidget listens for events on the
    input_channel data channel of the datasource and publishes
    a given message with parameter output_channel whenever such
    an event happens.

    The MediatorWidget has 4 main parameters:
    - input_channel: it listens to events on this datasource channel
    - output_channels: the datasource channels to give as a parameter
        when an event on input_channel happens
    - message: the message to send to the datasource
        (can be '/refresh', '/scroll', etc., anything
        that receivs a list of channels as a parameter).
        Default value: 'refresh'.
###
define ['cs!channels_utils', 'cs!widget'], (channels_utils, Widget) ->
    class MediatorWidget extends Widget
        params_defaults:
            'message': '/refresh'
            'input_channel': 'data-params'
            'input_channels': 'data-params'
            'output_channel': 'data-params'
            'output_channels': 'data-params'
            'skip_first': 'data-params'

        initialize: =>
            if @input_channel?
                @input_channels = [@input_channel]
            if @output_channel?
                @output_channels = [@output_channel]
            @first = true

            # Subscribe to the input channels
            @subscribed_channels = @input_channels
            @aggregated_channels = {get_input_channels: @subscribed_channels}

        get_input_channels: (params...) =>
            ###
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

            result = {}
            for channel_params in params
                _.extend(result, @translateParams(channel_params))
            pipe = loader.get_module('pubsub')
            for channel in @output_channels
                translated_output_channel = @channel_mapping[channel]
                msg = {}
                msg[translated_output_channel] = result
                pipe.publish(@message, msg)

        translateParams: (params) ->
            ###
                Translates parameters from the input_channel format
                to the format accepted by the output channel.

                Override this in your mediator class to pass whatever parameters
                you like to the output channel.
            ###
            params.model.toJSON()

    return MediatorWidget