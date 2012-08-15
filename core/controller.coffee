# Layout-based controller

define ['cs!layout', 'cs!widget'], (Layout, Widget) ->

    class Controller extends Widget

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
            # Set a clean page title when a new Controller is instantiated
            Utils.setTitle(null)

            page_title = @config.page_title

            # If page_title is configured in urls.js for the controller
            # use that, otherwise use controller name
            Utils.setTitle({page: page_title}) if page_title?

    return Controller