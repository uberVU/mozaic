define ['cs!module'], (Module) ->
    class WidgetStarter extends Module
        ###
            Monitors the DOM for the appearance of new widgets.
            Loads them up whenever they appear.

            TODO: find better method than setTimeout(), especially for IE
        ###
        constructor: ->

        widgetCheckInterval: 50 # ms
        checkIntervalForRemovedWidgets: 1000

        initialize: =>
            setInterval(@checkForNewWidgets, @widgetCheckInterval)
            setInterval(@checkForRemovedWidgets, @checkIntervalForRemovedWidgets)

        checkForRemovedWidgets: =>
            for widget_id of loader.widgets
                if $("[data-guid='#{widget_id}']").length == 0
                    loader.widgets[widget_id].destroy()
                    delete loader.widgets[widget_id]

        widgetCanBeStarted: (params) =>
            ###
                Checks if a widget can be started.
                The main reason for which widgets can't be started is that
                the datasource hasn't initialized all the data channels
                they are subscribed to.
            ###
            # No subscribed channels means no obligations :-)
            if not ('channels' of params)
                return true

            datasource = loader.get_module('datasource')
            # For each subscribed channel
            for k, v of params.channels
                if (not (v of datasource.data)) or (not (v of datasource.meta_data))
                    return false
            true

        checkForNewWidgets: =>
            ###
                Checks for newly appeared widgets in the DOM.
            ###
            $('body').find('.uberwidget').not('.uberinitialized').each((idx, el) =>
                # First thing, add the class that marks the fact we're processing
                # this widget, in order to prevent double processing for it
                $(el).addClass('uberinitialized')

                # Generate a random GUID as an id for the widget.
                # This is because there is no easy way to generate an unique ID
                # for the widget.
                widget_id = _.uniqueId('widget-')

                # Keep logging ..
                name = $(el).data('widget')

                # Write the GUID to the DOM so that we can debug the widget later :-)
                $(el).attr('data-guid', widget_id)

                # Extract widget initialization parameters from the DOM
                params = $.parseJSON($(el).attr('data-params')) or {}
                params['el'] = $(el)
                params['name'] = name
                params['widget_id'] = widget_id

                # If widget can be started right now, give it a go
                if @widgetCanBeStarted(params)
                    logger.info("Initializing widget #{name} (id = #{widget_id})")
                    # Call the loader to instantiate our widget
                    loader.load_widget(name, widget_id, params)
                # Otherwise, we will keep trying :)
                else
                    $(el).removeAttr('data-guid')
                    $(el).removeClass('uberinitialized')
            )

    return WidgetStarter
