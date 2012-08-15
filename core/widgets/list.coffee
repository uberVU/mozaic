define ['cs!scrollable_widget'], (ScrollableWidget) ->

    class WidgetList extends ScrollableWidget
        ###
            Generic Widget: receives a collection and injects
            a list of widgets. This handles common operations like
            add/remove and also has filtering/sorting support.
        ###
        subscribed_channels: ['/items']

        params_defaults:
            enable_scroll: 'data-params'
            className: 'data-params'
            item: 'data-params'
            item_channels: 'data-params'
            item_params: 'data-params'
            filter_by: 'data-params'
            sort_by: 'data-params'
            container: 'data-params'
            item_element: 'data-params'
            prepend: 'data-params'

        widget_params: {}

        initialize: =>
            # If the scroll is enabled in the params, then make
            # the items channel a scrollable one
            if @enable_scroll
                @scrollable_channels = ['/items']

            @getItemParams()

            # Make sure that sort_by is actually a dict
            # with keys as filtering criteria and values as
            # comparator types ('str' and 'int' supported so far).
            # So, if I want to filter by folder_id first, which is an
            # int folder, and by name afterwards, I would give it
            # {folder_id: 'int', name: 'str'}
            if @sort_by?
                if $.isArray(@sort_by)
                    new_sort_by = {}
                    for field in @sort_by
                        new_sort_by[field] = 'str'
                    @sort_by = new_sort_by
                else if (not $.isPlainObject(@sort_by))
                    field = @sort_by
                    @sort_by = {field: 'str'}

            # Initialize the array of IDs
            @ids = []

            super()

        compare: (a, b) =>
            ###
                Compares two models a and b with the criteria given by
                @sort_by. Follows the normal comparator convention and returns
                the equivalent of a - b, that is:
                -1, if a < b
                0, if a == b
                1, if a > b
            ###
            for field, comparator of @sort_by
                va = a.get(field)
                vb = b.get(field)
                if comparator == 'str'
                    if String(va) < String(vb)
                        return -1
                    if String(va) > String(vb)
                        return 1
                if comparator == 'int'
                    if Number(va) < Number(vb)
                        return -1
                    if Number(va) > Number(vb)
                        return 1
            return 0

        matchesFilters: (model) =>
            ###
                Checks if the model corresponds to the given filtering criteria.
            ###
            return true unless @filter_by?
            for k, v of @filter_by
                if String(model.get(k)) != String(v)
                    return false
            return true

        get_items: (item_params) =>

            if item_params.type == 'reset'
                # TODO(andrei): refactor this with getEl once Bogdan
                # merges that stuff into master
                @el.html('')
                @ids = []
                item_params.collection.each( (model) =>
                    if @matchesFilters(model)
                        @insertItem(model, item_params.collection)
                )

            # Add a new item to a list by injecting a widget to the end of it
            if item_params.type == 'add'
                if @matchesFilters(item_params.model)
                    @insertItem(item_params.model, item_params.collection)

            # If the event is `change_attribute`, check if the model matches the
            # filters and decide whether to add it or not
            if item_params.type == 'change_attribute'
                if @matchesFilters(item_params.model)
                    # Don't create duplicates and add it only if it is unique
                    if @el.find(".item-#{item_params.model.id}").length == 0
                        @insertItem(item_params.model, item_params.collection)

            # Delete a specific item from a list
            if item_params.type == 'remove'
                if @matchesFilters(item_params.model)
                    @deleteItem(item_params.model, item_params.collection)

        insertItem: (model, collection) =>
            ###
                Insert a specific item widget for a list
            ###
            _.extend @widget_params,
                id: model.id
                channels: @item_channels

            ###
                User can send an item_params which is send in as params in items
            ###
            _.extend(@widget_params, @item_params) if @item_params?

            # Also add a class to uniquely identify the item
            # Needed when deleting the item from the list
            class_name = if !@className then "item-#{model.id}" else "#{@className} item-#{model.id}"

            if @sort_by?
                # No element so far means that the insertion is straight forward
                if @ids.length == 0
                    Utils.injectWidget(@el, @item, @widget_params, class_name, null, @item_element ? 'li')
                    @ids.push(model.id)
                    return

                # Otherwise, see where in the list we can insert it
                # See if we must insert it before the first model
                first_model_so_far = collection.get(_.first(@ids))
                if @compare(model, first_model_so_far) <= 0
                    Utils.injectWidget(@el, @item, @widget_params, class_name, null, @item_element ? 'li', false, true)
                    @ids.unshift(model.id)
                    return

                # See if we must insert it after the last model
                last_model_so_far = collection.get(_.last(@ids))
                if @compare(model, last_model_so_far) > 0
                    Utils.injectWidget(@el, @item, @widget_params, class_name, null, @item_element ? 'li')
                    @ids.push(model.id)
                    return

                # Otherwise, we're inserting it somewhere in the middle
                # Also, it means that we have at least two elements in
                # @ids (because if there is only one, the element e will
                # either be <= it and be inserted before, or be > it and
                # be inserted after).
                for i in [0..@ids.length-2]
                    cur_model = collection.get(@ids[i])
                    next_model = collection.get(@ids[i+1])
                    if @compare(cur_model, model) < 0 and @compare(model, next_model) <= 0
                        @ids.splice(i, 0, model.id)
                        dom_element = @el.find(".item-#{next_model.id}")
                        # Insert before next_model's DOM element
                        Utils.injectWidget(dom_element, @item, @widget_params, class_name, null, @item_element ? 'li', false, @prepend, true)
                        return
            else
                Utils.injectWidget(@el, @item, @widget_params, class_name, null, @item_element ? 'li', false, @prepend)

        deleteItem: (model, collection) =>
            ###
                Deletes a specific item from a list
            ###

            # Erase the ID of the model from the IDs array
            idx = @ids.indexOf(model.id)
            @ids.splice(idx, 1)

            # Remove the DOM element
            @el.find(".item-#{model.id}").remove()

        getItemParams: =>
            ###
                User can send an item_params which is send in as params in items
            ###
            _.extend(@widget_params, @item_params) if @item_params?
