# Layout-based controller

define ['cs!layout', 'cs!module'], (Layout, Module) ->
    CLEANUP_CSS_FOR = ['body']

    injectControllerInterval = null

    class ApplicationController extends Module

        constructor: (page_template) ->
            @page_template = page_template

        initialize: =>

        renderLayout: (layout_params = {}, stringify = true) =>
            @layout = new Layout(@page_template, layout_params)
            @layout.renderHTML(null, stringify)

        action: (controller, params, callback) =>
            @renderLayout()
            callback()

        remove_css_classes: =>
            for element in CLEANUP_CSS_FOR
                $(element).attr('class', '')

        bootstrapModules: ->
          ###
            Return the current modules that should be started
            at the bootstrap process. In particular, this means
            that you can customize the list in your own derived
            application controller.
          ###
          return ['cs!datasource', 'cs!loading_animation', 'cs!modal_window']

        injectController: (new_controller_config, controller_params) =>
            if $('#controller-container').length > 0
                clearInterval(injectControllerInterval)
                Utils.injectWidget($('#controller-container'),
                                           new_controller_config.controller,
                                           controller_params,
                                           new_controller_config.controller)

        new_controller: (new_controller_config, url_params) =>
            #before doing any loading, intercept uncaught errors
            window.onerror = (errorMsg, url, lineNumber) ->
                logger.error(url + " : " + errorMsg)
            # Remove any css classes that were added on certain
            # global elements, like body because the new page
            # may not need it
            @remove_css_classes()

            loader.load_modules ['cs!pubsub'], =>
                loader.load_modules ['cs!widget_starter'], =>
                    loader.load_modules @bootstrapModules(), =>
                        inject_callback = (extra_params) =>
                            controller_params =
                                config: new_controller_config
                                url_params: url_params
                                template_name: new_controller_config.layout
                                channels: @controller_channels
                            _.extend(controller_params, extra_params)

                            # Scroll to the top of the viewport before injecting
                            # the controller. When going from controller to controller
                            # the scroll is kept and this triggers a weird behaviour
                            # when you go from scrolled mentions to the analytics section:
                            # no analytics shown, but if you scroll to the top you can
                            # see it
                            window.scrollTo(0, 0)

                            # Because the callback is called too soon, the DOM may not be
                            # ready sometimes. Just to be sure that an element with id
                            # controller-container is present in the DOM
                            injectControllerInterval = setInterval( =>
                                    @injectController(new_controller_config, controller_params)
                                , 20
                            )

                        delete_callback = =>
                            $('#controller-container').html('')

                        @action(new_controller_config, url_params,
                                inject_callback, delete_callback)

    return ApplicationController