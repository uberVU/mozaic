define ['cs!widget'], (Widget) ->

    class ItemCountWidget extends Widget
        subscribed_channels: ['/count']
        template_name: 'templates/item-count.hjs'

        params_defaults:
            single_item: 'data-params'
            multiple_items: 'data-params'
            path: 'data-params'
            collection: 'data-params'
            icon: 'data-params'

        params_required: ['single_item', 'multiple_items', 'path']

        get_count: (params) =>
            ###
                Whenever a new mention count arrives, display it.
            ###

            # Just in case nothing is filled in to avoid displaing undefined or undefineds  
            @single_item = @single_item ? ''          
            @multiple_items = @multiple_items ? (if @single_item? and @single_item isnt '' then  @single_item + 's' else '' )
            
            if @collection
                item_count = params.collection.length
            else if @path
                item_count = params.model.get(@path)
            else
                item_count = 0
            @renderLayout(
                count: item_count
                items: if item_count == 1 then @single_item else @multiple_items
                icon: @icon
            )

    return ItemCountWidget