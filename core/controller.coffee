# Layout-based controller

define ['cs!layout', 'cs!module'], (Layout, Module) ->
    class Controller extends Module
        constructor: (config) ->
            @config = config

        initialize: ->

        destroy: ->

        action: ->

        build_url: ->

        renderLayout: (params) ->
            @layout = new Layout(@config.layout, params)
            @layout.renderHTML(null, true)

    return Controller