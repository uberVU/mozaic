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
        skip_fake_events: true
        
        params_defaults:
            'message': '/refresh'
            'input_channel': 'data-params'
            'output_channels': 'data-params'
        
        initialize: =>
            # Create the subscribed_channels key automatically
            @subscribed_channels = [@input_channel]
            
            # Generate the function for listening to events on the
            # input channel automatically
            [collection, item, events] = channels_utils.splitChannel(@input_channel)
            method_name = 'get_' + collection
            
            @[method_name] = (params) =>
                pipe = loader.get_module('pubsub')
                
                for channel in @output_channels
                    translated_output_channel = @channel_mapping[channel]
                    translated_params = @translateParams(params, channel)
                    msg = {}
                    msg[translated_output_channel] = translated_params
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