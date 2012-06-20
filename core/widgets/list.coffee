define ['cs!widget'], (Widget) ->

    class WidgetList extends Widget
        ###
            Generic Widget: receives a collection and injects a list of widgets into the page

        ###
        subscribed_channels: ['/items']
        template_name: 'templates/generic_widget_list.hjs'

        params_defaults:
            className: 'data-params'
            item: 'data-params'
            item_channels: 'data-params'
            item_params: 'data-params'

        initialize: () ->
            @renderLayout()

        get_items: (item_params) =>

            if item_params.type == 'reset'
                item_params.collection.each( (item) =>
                    @insertItemWidget(item)
                )

            # When a new item is added inject its widget at the end of the item list
            if item_params.type == 'add'
                @insertItemWidget(item_params.model.toJSON())

        insertItemWidget: (item) =>
            ###
                Insert a specific item widget for an item
            ###
            widget_params =
                id: item.id
                channels: @item_channels

            ###
                User can send an item_params which is send in as params in items
            ###
            _.extend(widget_params, @item_params) unless !@item_params?
            Utils.injectWidget(@el, @item, widget_params, @className, null, 'li')

