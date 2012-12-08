define ['cs!widget'], (Widget) ->

    class NewItemCountWidget extends Widget
        subscribed_channels: ['/items', '/filters']
        template_name: 'templates/new-items-count.hjs'
        events:
            "click .item-refresh-link a": "refreshItems"
        params_defaults:
            'single_item':      'data-params'
            'multiple_items':   'data-params'
        bound_to_buffer: false


        refreshItems: (event) =>
            ###
                Whenever the user wants to see the latest mentions,
                refresh the mentions channel and hide the new mentions counter.
            ###

            # First, scroll to the top because the new mentions count
            # is shown permanently as an overlay. This will allow the user
            # to actually see the new mentions being inserted into the DOM.
            $('html, body').animate({scrollTop:0}, 'slow')

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
                # Check that the items from the buffer are actually not
                # part of the underlying collection (a.k.a. they are truly new).
                # Duplicated items sometimes arrive due to a race in DataSource.
                length = 0
                for item in translated.collection.models
                    if not translated.collection.collection.get(item.id)
                        length = length + 1
                if length > 0
                    @el.show()
                    if length > 100
                        length = '> 100'
                    items = @multiple_items
                    if length == 1 and @single_item?
                        items = @single_item

                    # Modify page title to let the user know there are some new items
                    Utils.setTitle(count: length)
                    @renderLayout({result: length, timespan: new Date(), items: items})
                else
                    Utils.setTitle(count: 0)
                    @el.hide()

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
            @el.hide()

        destroy: =>
            super()
            # TODO: somehow unbind from the buffer

    return NewItemCountWidget