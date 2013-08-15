define [], () ->

    class ListItemParamsMixin

        getItemWidgetParams: (model, extra_params) ->
            ###
                Method returns the params of the item widget which will be inserted as part of the current list.
                Can be overridden in specialiazed list classes to provide custom params to list items.
                @param {Object} model Backbone.Model instance of the item to be inserted
                @param {Object} extra_params - extra params to be passed to item widgets
                @return {Object}
            ###
            item_widget_params =_.extend {}, @widget_params, extra_params,
                id: model.id
                channels: @getItemWidgetChannels(model)

            item_widget_params = _.extend({}, item_widget_params,
                                          @itemParamsFromModel(model, @item_model_params))

            item_widget_params

        getItemWidgetName: (model) ->
            ###
                Get the widget name to inject. This could be found
                in the mappings dict, using the object_class returned
                from API, or if undefined, use the generic @item type
                provided from parent.
            ###
            name = @item or @mappings?[model.get(@object_class_key)]?.item
            unless name
                logger.error "The list cannot render a model with no specified type."
            return name

        getItemWidgetChannels: (model) ->
            @item_channels or @mappings?[model.get(@object_class_key)]?.item_channels or @channel_mapping

        itemParamsFromModel: (model, dict = {}) ->
            response = _.extend {}, (@item_params or
                                     @mappings?[model.get(@object_class_key)]?.item_params)
            for key, new_key of dict
                data = model.get(key)
                response[new_key] = data if data
            return response

        extendWidgetParamsFromItem: ->
            ###
                User can send an item_params which is send in as params in items
            ###
            _.extend({}, @widget_params, @item_params) if @item_params?
