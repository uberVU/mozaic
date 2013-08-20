define ['cs!widget'], (Widget) ->

    class NewItemCountWidget extends Widget

        subscribed_channels: ['/items', '/filters']
        template_name: 'templates/new-items-count.hjs'
        events:
            "click .item-refresh-link a": "refreshItems"
        params_defaults:
            'single_item': 'data-params'
            'multiple_items': 'data-params'
            # Use the scroll of the entire window if not specific scrollable
            # target has been specified
            'scrollable_target': (target) -> target or 'html, body'
        bound_to_buffer: false


        refreshItems: (event) =>
            ###
                Whenever the user wants to see the latest mentions,
                refresh the mentions channel and hide the new mentions counter.
            ###

            # First, scroll to the top because the new mentions count
            # is shown permanently as an overlay. This will allow the user
            # to actually see the new mentions being inserted into the DOM.
            $(@scrollable_target).animate(scrollTop: 0, 'slow')

            # Ask for a fresh batch of mentions. These might come from the
            # streampoll buffering mechanism immediately.
            @refreshChannel('/items')
            return false

        get_items_buffer: (type, params...) =>
            ###
                This function is subscribed to the events of the mention buffer.
                Since it's not subscribed through the widget mechanisms
                (but manually), we will translate the event params manually.
            ###
            translated = @_translateEventParams('collection', type, params...)
            if translated and translated.collection
                # - translated.collection points to the buffer
                # - translated.collection.collection points to the collection
                #     of the buffer (thus the original collection)
                length = translated.collection.collection.new_items_in_buffer()
                displayed_length = (if length <= 100 then length else '> 100')

                if length > 0
                    @view.$el.show()
                    items = @multiple_items
                    if length == 1 and @single_item?
                        items = @single_item
                    @renderLayout(
                        result: displayed_length
                        timespan: new Date()
                        items: items
                    )
                else
                    @view.$el.hide()

        get_items: (params) =>
            ###
                Whenever a whole new mentions collection has arrived,
                subscribe the local widget to its buffer's events.
            ###
            if params.collection and not @bound_to_buffer
                @bound_to_buffer = true
                if params.collection and params.collection.buffer
                    params.collection.buffer.on('all', @get_items_buffer)

        get_filters: (filters_params, mentions_params) =>
            ###
                Whenever the user selects a new value for filters,
                hide the current item count because it's invalid.
            ###
            @view.$el.hide()

        destroy: =>
            super()
            # TODO: somehow unbind from the buffer

    return NewItemCountWidget