# Layout-based controller

define ['cs!layout', 'cs!widget'], (Layout, Widget) ->

    class Controller extends Widget

        constructor: (params, template = null) ->
            @config = params.config
            @url_params = params.url_params
            super(params, template)

        initialize: =>
            $("body").attr('class', '')
            @createChannels(@url_params...)
            @action(@url_params...)
            pipe = loader.get_module('pubsub')
            pipe.publish('/new_controller', {controller: @})

        action: ->

        createChannels: ->

    return Controller