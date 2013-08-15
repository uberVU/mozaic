define [], () ->

    class ListItemManagementMixin

        matchesFilters: (model) ->
            ###
                Checks if the model corresponds to the given filtering criteria.
            ###
            return true unless @filter_by?
            for k, v of @filter_by
                if String(model.get(k)) != String(v)
                    return false
            return true

        findModelById: (id, models) ->
            ###
                Given a list of models, find one of them by ID.

                We lose efficiency - O(N) search but we gain flexibility,
                allowing us to work with derived classes that combine multiple
                channels by aggregating them.
            ###
            for model in models
                if model.id == id
                    return model
            return null

        get_items: (item_params) ->
            @handleChannelEvents(item_params)

        getModelsFromChannelData: (item_params) ->
            ###
                Get models from one or more channel events. The default list
                implementation only uses an /items channel to draw its items
                from
            ###
            return item_params.collection?.models or []

        handleChannelEvents: (item_params) ->
            ###
                Method for processing channel data and inserting received items
                onto the list. It is called w/ the single /items channel from
                its channel callback method in the default implementation, but
                can be used in subclasses to have additional channels that
                construct the list's items. The items from more than one
                channel can be aggregated using the @getModelsFromChannelData
                method, which receives all arguments that this method received,
                which can be a list of channel events
            ###
            model = item_params.model
            models = @getModelsFromChannelData(arguments...)

            # Detecting whether we need to re-render the entire list is tricky,
            # we need a reset event on at least one channel, and either reset
            # or no_data on the others.
            # TODO(andrei): WTF? don't understand the no_data part at all
            events = _.pluck(arguments, 'type')
            isResetEvent = 'reset' in events and
                           _.difference(events, ['reset', 'no_data']).length is 0
            if isResetEvent
                @list_items = []
                @renderLayout()
                @insertItems(models)

            # Add a new item to a list by injecting a widget to the end of it
            else if item_params.type == 'add'
                # Create a dummy model id if missing. This can only happen if a
                # list is hosting client-side volatile data that is not synced
                # with a database (by adding to channel with sync: false)
                unless model.id?
                    # Prevent from triggering a change/change_attribute event
                    # as well, by setting with silent: true
                    model.set('id', Utils.guid('new'), silent: true)
                if @matchesFilters(model)
                    @insertItem(model, models, isLoadedLater: true)

            # If the event is `change_attribute`, check if the model matches the
            # filters and decide whether to add it or not
            else if item_params.type == 'change_attribute'
                if @matchesFilters(model)
                    # If we have a change in one of the sort_by attributes, we
                    # need to remove this item and add it again, to go through
                    # all the insert-in-sorted-place logic. And will be added
                    # by the right below code again.
                    if item_params.attribute in @getSortByFields()
                        @deleteItem(model)
                    # Don't create duplicates and add it only if it is unique
                    if @view.$el.find(".item-#{model.id}").length == 0
                        @insertItem(model, models)

            # Delete a specific item from a list
            else if item_params.type == 'remove'
                if @matchesFilters(model)
                    @deleteItem(model)

            @postProcessListItems()

        insertItems: (models) ->
            ###
                Batch insert, for adding more models at the same time on
                'reset' events. Useful for subclasses that might aggregate more
                than one channel to build its list items
            ###
            # Insert each item one by one
            for model in models
                if @matchesFilters(model)
                    @insertItem(model, models)

        insertItem: (model, models, options = {}) ->
            ###
                @param {Object} options
                @param {Boolean} [options.isLoadedLater] - mark the item as being
                                                        loaded after view refresh
            ###
            _.defaults options,
                 isLoadedLater: false

            # Extra params of the widget.
            extra_params = _.pick(options, 'isLoadedLater')
            item_widget_params = @getItemWidgetParams(model, extra_params)

            # Also add a class to uniquely identify the item
            # Needed when deleting the item from the list
            item_class = "item-#{model.id}"
            item_class += " #{@item_class}" if @item_class?

            injectOptions =
                params: item_widget_params
                container: @view.$el
                type: @item_element
                classes: item_class
                data:
                    id: model.get(@id_field)

            if @minimize_dom_nodes
                # Widgets will be initialized only when they are in viewport
                injectOptions.data.delayed = true
                # In order to preserve the space for a widget removed from DOM
                # we need to wrap the widget in a container that will have
                # fixed height as long as the widget is not initialized
                injectOptions.wrappedInject = true
                injectOptions.data.wrapped = true

            current_item =
                id: model.id
                model: model
                # By default DOM nodes are visible if minimize_dom_nodes is off.
                visible: if @minimize_dom_nodes then false else true

            # No sorting or no elements so far means that the insertion is
            # straight forward.
            if (not @sort_by? or @list_items.length is 0)
                @list_items.push(current_item)
            else
                firstModel = @findModelById(_.first(@list_items).id, models)
                lastModel = @findModelById(_.last(@list_items).id, models)

                # See if we must insert it before the first model.
                if @compare(model, firstModel) <= 0
                    @list_items.unshift(current_item)
                    injectOptions.placement = 'prepend'

                # See if we must insert it after the last model.
                else if @compare(model, lastModel) > 0
                    @list_items.push(current_item)

                # Otherwise, we're inserting it somewhere in the middle
                # Also, it means that we have at least two elements in
                # @list_items (because if there is only one, the element e will
                # either be <= it and be inserted before, or be > it and
                # be inserted after).
                else
                    for i in [0..@list_items.length-2]
                        cur_model = @findModelById(@list_items[i].id, models)
                        next_model = @findModelById(@list_items[i+1].id, models)
                        if @compare(cur_model, model) < 0 and
                           @compare(model, next_model) <= 0
                            @list_items.splice(i + 1, 0, current_item)
                            # Insert before next_model's DOM element
                            injectOptions.container =
                                @view.$el.find(".item-#{next_model.id}")
                            injectOptions.placement = 'before'
                            break

            if options.override_inject_options?
                _.extend injectOptions,
                    options.override_inject_options

            return Utils.inject(@getItemWidgetName(model), injectOptions)

        deleteItem: (model) ->
            ###
                Deletes a specific item from a list
            ###

            # Find the item to delete by its id
            item_to_delete = _.find(@list_items, (item) -> item.id is model.id)
            if not item_to_delete
                logger.warn("Trying to delete unexisting item #{model.id} from list")
                @postProcessListItems()
                return

            # Delete it from both the internal list and from the DOM
            # (which will trigger widget_starter's GC for that widget)
            idx = _.indexOf(@list_items, item_to_delete)
            @list_items.splice(idx, 1)
            @view.$el.find(".item-#{model.id}").remove()
