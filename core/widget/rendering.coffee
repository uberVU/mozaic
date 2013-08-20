define ['cs!layout'], (Layout) ->

    class WidgetRenderingMixin
        ###
            This class contains all rendering-related functionality
            of the Mozaic widget.
        ###

        preRender: ->
            ###
                Run widget's defined pre processors if there are some before
                the widget is rendered.
            ###
            for process, options of @pre_render
                ContextProcessors.process(process, @view.$el, options) if @view?

        postRender: ->
            ###
                Run widget's defined post processors if there are some after
                the widget is rendered.
            ###
            for process, options of @post_render
                ContextProcessors.process(process, @view.$el, options) if @view?

        renderLayout: (layout_params = {}, stringify = true) ->
            ###
                Execute preRender specific widget method before the
                widget is rendered.
            ###
            unless @view?
                logger.warn "You are calling render on a detached widget named #{@params.name}"
                return
            @preRender()

            layout = new Layout(@template_name, layout_params)
            layout.renderHTML(@view.$el, stringify, =>
                if @view.$el.data('wrapped') is true
                    @view.$el.parent().css('height': '')
            )

            # DOM element parsing must be done as early as possible after
            # layout.renderHTML(). The logic is that if I try to use those
            # elements in a handler for /new_widget_rendered, for example,
            # it will crash.
            @_parseDomElements()

            # We can manually trigger the /new_widget_rendered signal
            # using @widgetRenderedOnDemand method where needed
            unless (@rendered_signal_sent or @WIDGET_RENDERED_ON_DEMAND)
                @triggerNewWidgetRendered()
            # Trigger the /widget_rendered event every time the widget
            # renders. The /new_widget_rendered on the other hand is
            # triggered only once.
            @triggerWidgetRendered()

            ###
                Execute postRender widget method after the widget
                was rendered.
            ###
            @postRender()

        triggerWidgetRendered: ->
            pipe = loader.get_module('pubsub')
            pipe.publish('/widget_rendered', @params['widget_id'], @params['name'])

        triggerNewWidgetRendered: ->
            pipe = loader.get_module('pubsub')
            pipe.publish('/new_widget_rendered', @params['widget_id'], @params['name'])
            @rendered_signal_sent = true
