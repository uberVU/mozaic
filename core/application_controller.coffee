define ['cs!layout', 'cs!mozaic_module'], (Layout, Module) ->
    injectControllerInterval = null

    class ApplicationController extends Module
        # Layout-based controller

        constructor: (page_template) ->
            super()
            @page_template = page_template

        initialize: =>

        renderLayout: (layout_params = {}, stringify = true) =>
            layout = new Layout(@page_template, layout_params)
            layout.renderHTML(null, stringify)

        action: (controller, params, injectControllerCallback, deleteControllerCallback) =>
            @renderLayout()
            deleteControllerCallback()
            injectControllerCallback()

        bootstrapModules: ->
            ###
                Return the current modules that should be started
                at the bootstrap process. In particular, this means
                that you can customize the list in your own derived
                application controller.
            ###
            modules = ['cs!datasource', 'cs!loading_animation', 'cs!modal_window']
            return modules

        injectController: (new_controller_config, controller_params) =>
            ###
                #TODO(andrei): very very strange bug causing the code
                to not see the $('#controller-container') div although
                it's right there in the DOM. We keep waiting in 20ms
                increments until it's there.
            ###
            if $('#controller-container').length > 0
                clearInterval(injectControllerInterval)
                Utils.injectWidget($('#controller-container'),
                                   new_controller_config.controller,
                                   controller_params,
                                   new_controller_config.controller)

        new_controller: (new_controller_config, url_params) =>
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
                                    @injectController(new_controller_config,
                                                      controller_params)
                                , 20
                            )

                        delete_callback = =>
                            controller = $('#controller-container')

                            ###
                                Emptying $('#controller-container') might not
                                be synchronous with the call to
                                    widget_starter.checkRemovedNode()
                                because on IE we're using setTimeout() in order
                                to check for disappeared widgets. This is why
                                we will manually call it, to ensure that it
                                gets called before the next controller gets
                                injected.
                            ###
                            widget_starter = loader.get_module('widget_starter')
                            widget_starter.checkRemovedNode(controller)

                            # The previous call marked the widgets as detached
                            # from DOM, but this didn't correspond to reality.
                            # Make this right ASAP :)
                            controller.html('')

                            # Calling checkRemovedNode() only marks widgets
                            # for GC, but the next round of GC will be run
                            # asynchronously, and we need to forcedly GC
                            # "urgent_for_gc" widgets (such as mediators)
                            # that can mess the transition from one controller
                            # to another. Therefore, we manually call GC
                            # and know for sure that these guys will be put to
                            # sleep NOW :)
                            widget_starter.garbageCollectWidgets()

                        @action(new_controller_config, url_params,
                                inject_callback, delete_callback)

    return ApplicationController
