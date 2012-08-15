define ['cs!widget'], (Widget) ->

    class ItemCountWidget extends Widget
        template_name: 'templates/item-count.hjs'

        params_defaults:
            single_item: 'data-params'
            multiple_items: 'data-params'
            path: 'data-params'
            value: 'data-params'
            collection: 'data-params'
            icon: 'data-params'
            id: 'data-params'
            color: 'data-params' # used to give a color to the text
            text_first: 'data-params' # in some cases the text needs to go before the number
            suffix: 'data-params' # show somethingafter the number, like % sign
            prefix: 'data-params' # put something before the number, like a + sign
            max_value: 'data-params' # if the number is greater than max_value, display max_value

        params_required: ['single_item', 'multiple_items', 'path']

        initialize: =>
            # If the value to be displayed is received in data-params,
            # render the layout with this value and the other options
            # and ignore the channels.
            # This fixed was made because sometimes the location percentages
            # were not shown

            if @value?
                @render(@value)
            else
                # Subscribe the widget to /count channel
                @subscribed_channels = ['/count']

        get_count: (params) =>
            ###
                Whenever a new mention count arrives, display it.
            ###
            if params.type == 'invalidate'
                return

            if params.type == 'change' or params.type == 'reset' or params.type == 'remove' or params.type == 'add'

                # Just in case nothing is filled in to avoid displaying undefined or undefineds
                @single_item = @single_item ? ''
                @multiple_items = @multiple_items ? (if @single_item? and @single_item isnt '' then  @single_item + 's' else '' )

                if @collection
                    item_count = params.collection.length
                else if @path
                    item_count = params.model.get(@path)
                else
                    item_count = 0

                @render(item_count)

        render: (item_count) =>
            if item_count == 0 or item_count == null
                @el.hide()
                return

            @el.show()

            # Avoid showing +0 or -0 if the prefix is a + or - sign
            @prefix = if (@prefix in ['+', '-'] and item_count is 0) then null else @prefix

            # Determine if item_count is greater than max_value
            item_count = @max_value if @max_value? and item_count > @max_value

            @renderLayout(
                count: item_count
                items: if item_count == 1 then @single_item else @multiple_items
                icon: @icon
                id: @id
                style: if @color? then " style=color:#{@color}; "
                text_first: @text_first
                suffix: if @suffix? then @suffix
                prefix: if @prefix? then @prefix
            )

    return ItemCountWidget