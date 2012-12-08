# Layout-based controller

define ['cs!layout', 'cs!widget'], (Layout, Widget) ->

    class Controller extends Widget
        # All controllers have priority when it comes to garbage collection
        URGENT_FOR_GC: true

        constructor: (params, template = null) ->
            @config = params.config
            @url_params = params.url_params
            @pipe = loader.get_module('pubsub')
            super(params, template)

        initialize: =>
            @setPageTitle()
            @createChannels(@url_params...)
            @pipe.publish('/new_controller', {controller: @})
            @action(@url_params...)

        action: ->

        createChannels: ->

        setPageTitle: ->
            # If page_title is configured in urls.js for the controller
            # use that, otherwise use controller name
            page_title = @config.page_title or @config.controller
            Utils.setTitle(page: page_title)

    return Controller
