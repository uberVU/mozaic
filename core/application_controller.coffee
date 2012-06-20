# Layout-based controller

define ['cs!layout', 'cs!module'], (Layout, Module) ->
    class ApplicationController extends Module

        constructor: (page_template) ->
            @page_template = page_template

        initialize: =>

        renderLayout: (layout_params = {}, stringify = true) =>
            @layout = new Layout(@page_template, layout_params)
            @layout.renderHTML(null, stringify)

        action: (controller, params, callback) ->
            @renderLayout()
            callback()

        new_controller: (new_controller_config, url_params) =>
            modules = ['cs!datasource', 'cs!loading_animation', 'cs!modal_window']

            loader.load_modules ['cs!pubsub'], =>
                loader.load_modules ['cs!widget_starter'], =>
                    loader.load_modules modules, =>
                        callback = =>
                            controller_params =
                                config: new_controller_config
                                url_params: url_params
                                template_name: new_controller_config.layout
                                channels: @controller_channels

                            # Scroll to the top of the viewport before injecting
                            # the controller. When going from controller to controller
                            # the scroll is kept and this triggers a weird behaviour
                            # when you go from scrolled mentions to the analytics section:
                            # no analytics shown, but if you scroll to the top you can
                            # see it
                            window.scrollTo(0, 0)

                            Utils.injectWidget($('#controller-container'),
                                           new_controller_config.controller,
                                           controller_params,
                                           new_controller_config.controller,
                                           true)

                        @action(new_controller_config, url_params, callback)

    return ApplicationController