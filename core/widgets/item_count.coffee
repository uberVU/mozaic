define ['cs!widget'], (Widget) ->

    class ItemCountWidget extends Widget
        subscribed_channels: ['/count']
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

        params_required: ['single_item', 'multiple_items', 'path']

        get_count: (params) =>
            ###
                Whenever a new mention count arrives, display it.
            ###
            if params.type == 'invalidate'
                return

            if params.type == 'change' or params.type == 'reset'

                # Just in case nothing is filled in to avoid displaying undefined or undefineds
                @single_item = @single_item ? ''
                @multiple_items = @multiple_items ? (if @single_item? and @single_item isnt '' then  @single_item + 's' else '' )

                if @collection
                    item_count = params.collection.length
                else if @path
                    item_count = params.model.get(@path)
                # This is useful only when the path is hard to get
                else if @value
                    item_count = @value
                else
                    item_count = 0

                if item_count == 0 or item_count == null
                    @el.hide()
                    return

                @el.show()

                # Avoid showing +0 or -0 if the prefix is a + or - sign
                @prefix = if (@prefix in ['+', '-'] and item_count is 0) then null else @prefix

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