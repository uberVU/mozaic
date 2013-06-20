define ['cs!scrollable_widget'], (ScrollableWidget) ->

    class List extends ScrollableWidget
        ###
            Widget which is able to render a list of items, by injecting
            one widget per each item. An item to be displayed will be named
            ListItem.

            Features:

                - not all widgets for all items must be the same. There is
                  a mappings parameter which specifies different parameters
                  and different channels for each type of widget. In order
                  to find out the correct param, the list takes into
                  account ListItem['object_class].

                - it's able to maintain a client-side sorted order for widgets,
                  depending on one or more criteria. For example, it can sort
                  by 'created_at' key descending as the primary key, and when
                  two items are tied, break the tie with the 'name' field.
                  It supports custom comparators for each field. Out of the box,
                  it supports ints, floats, strings and dates.

                - it keeps a CSS class on the first and last item of the
                  list, even when the list order changes. And the list order
                  might change because of a change in a field that's a sort key!
                  This is very useful for design issues.

                - it manages the lifecycle of the widgets corresponding to
                  ListItems, by removing them from the DOM when the item
                  is removed from the channel, or by adding new ones when
                  an item is added to a channel. It is also able to MOVE
                  around a widget, but by making a DELETE + INSERT (Mozaic
                  core doesn't yet support moving widgets around in DOM)

                - it can filter items from the collection and only display
                  those we're interested in. For example, say that I'm
                  fetching the list of all books from the server, and I want
                  to display only the books by a certain author.

                - while the list is built around an /items channel in the
                  default implementation, its interface allows having more than
                  one channel (using aggregated channels) for building the list
                  items. All channel events must be funneled into the
                  @handleChannelEvents method, and items are joined together
                  under the @getModelsFromChannelData method

            IMO lifecycle management of the widgets is the most important
            feature of this widget - if I want to display a list, I can
            concentrate on writing the widget for the list's item instead of
            repeating the same boilerplate code for removing the widget from
            DOM when it's removed from the channel, and so on.

        ###
        subscribed_channels: ['/items']
        loading_channels: ['/items']

        template_name : 'templates/list.hjs'

        params_defaults:
            enable_scroll: 'data-params'
            item: 'data-params'
            item_channels: 'data-params'
            item_params: 'data-params'
            item_class: 'data-params'
            # Used to specify what fields to dynamically extract
            # from model. Should look like {key1: new_key1, key2: new_key2, ..}
            # where key is the one in model, and new_key is the one will be used
            # as key.
            item_model_params: 'data-params'
            filter_by: 'data-params'
            sort_by: 'data-params'
            container: 'data-params'
            item_element: (value) -> value or 'li'
            prepend: 'data-params'
            # This mappings params is used to be able
            # to insert different widgets (with different
            # models).
            mappings: 'data-params'

        # A list of comparators for list. You can also push to
        # this list and define your own comparator in your type
        # of list.
        _comparators_map:
            str: 'strComparator'
            int: 'intComparator'
            float: 'floatComparator'
            date: 'dateComparator'
            bool: 'boolComparator'

        registerComparator: (key, comparator) ->
            ###
                Adds a comparator to the current list instance.
                @param {String} key
                @param {string} comparator - name of the method to be used as comparator
            ###
            unless _.isString(key) and _.isString(comparator)
                throw new Error "params `key` and `comparator` must both be strings"
            unless _.isFunction @[comparator]
                throw new Error "this.#{comparator} is not a function"
            @_comparators_map[key] = comparator

        widget_params: {}

        initialize: =>
            # If the scroll is enabled in the params, then make
            # the items channel a scrollable one
            if @enable_scroll
                # Make all loading channels scrollable because widget states
                # are triggered by loading ones and affect the scrollable ones
                @scrollable_channels = _.clone(@loading_channels)

            @extendWidgetParamsFromItem()

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
                    @sort_by = {}
                    @sort_by[field] = 'str'

            # Initialize the array of IDs
            @ids = []

            super()

        changeState: (state, params...) ->
            super(arguments...)
            if state == 'empty'
                # TODO: Add `end` state to widget base
                # Support multiple loading channels for building the list's
                # item feed
                if not @getModelsFromChannelData(params...).length
                    @renderLayout {state: state}
                else
                    # Maybe add something to the bottom of all items instead
                    Utils.notify(Constants.LOADING_END_NOTIFICATION, 'notice')

        loadingStart: () ->
            Utils.notify(Constants.LOADING_NOTIFICATION, 'loading')

        loadingEnd: () ->
            Utils.notify(null, 'loading')

        compare: (a, b) =>
            ###
                Goes through each @sort_by field until it finds difference
                between models. By default the order is ascending.

                One can give the following sort_by syntax:
                sort_by:
                    'pub_date desc': 'date'
                By default, sorting is 'asc'.

                The compare supports multiple fields of comparation, and
                in case of a tie, it goes comparint to the next field.
            ###
            for field, comparator of @sort_by
                # Set ascending as default order
                ascending = true

                # Search if order (asc/desc) is specified. Make sure field is
                # string.
                tokens = (""+field).split(' ')
                if tokens.length is 2
                    field = tokens[0]
                    switch tokens[1]
                        when 'asc' then ascending = true
                        when 'desc' then ascending = false
                        else ascending = true

                comparisonResult = @compareByField(a, b, field, comparator)
                # Return only if difference found, else continue
                # ordering by the next sort_by option.
                unless comparisonResult is 0
                    return if ascending then comparisonResult else -comparisonResult

            return 0

        compareByField: (a, b, field, comparator) ->
            ###
                Compares two models a and b with the criteria given by
                field. Follows the normal comparator convention and returns
                the equivalent of a - b, that is:
                -1, if a < b
                0, if a == b
                1, if a > b
            ###
            va = Utils.getAttributeFromModel(a, field)
            vb = Utils.getAttributeFromModel(b, field)
            # Get the comparison function, defined in COMPARATORS_MAP
            # constant above.
            f = @[ @_comparators_map[comparator] ]
            unless f
                logger.error "No comparison function for #{comparator} comarator type."
                return
            f.call this, va, vb

        intComparator: (a, b) ->
            a = parseInt(a, 10)
            b = parseInt(b, 10)
            a - b

        floatComparator: (a, b) ->
            a = parseFloat(a, 10)
            b = parseFloat(b, 10)
            a - b

        strComparator: (a, b) ->
            a = _.str.trim (a).toLowerCase()
            b = _.str.trim (b).toLowerCase()
            return -1 if a < b
            return 1 if a > b
            return 0

        boolComparator: (a, b) ->
            a = Boolean(a)
            b = Boolean(b)
            return -1 if b and not a
            return 1 if a and not b
            return 0

        dateComparator: (a, b) ->
            ###
                If you are comparing two dates that
                momentjs does not support, you should
                override this comparator and define
                your own format.
            ###
            f = Utils.getUTCTimestampFromDate
            return f(a) - f(b)

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
            @handleChannelEvents(item_params)

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
            events = _.pluck(arguments, 'type')
            isResetEvent = 'reset' in events and
                           _.difference(events, ['reset', 'no_data']).length is 0
            if isResetEvent and models.length
                # Render layout with "available" state flag
                @renderLayout {state: 'available'}
                @insertItems(models)

            # Add a new item to a list by injecting a widget to the end of it
            else if item_params.type == 'add'
                # Clear template blank state if previous state was "empty"
                # and no _reset_ event has been triggered in the meantime
                # The "empty" state is also triggered at the end of scrolling,
                # so we need to check that there were no previous items before
                # emptying the template
                if @data_state is 'empty' and models.length <= 1
                    @renderLayout {state: 'available'}
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

        insertItems: (models) ->
            ###
                Batch insert, for adding more models at the same time on
                'reset' events. Useful for subclasses that might aggregate more
                than one channel to build its list items
            ###
            @ids = []
            # Insert each item one by one
            _.each models, (model) =>
                @insertItem(model, models) if @matchesFilters(model)

        insertItem: (model, models, options = {}) =>
            ###
                @param {Object} options
                @param {Boolean} [options.isLoadedLater] - mark the item as being
                                                        loaded after view refresh
            ###
            _.defaults options,
                 isLoadedLater: false

            # Find the name of the widget to insert.
            item = @getItemWidgetName model
            # Skip the insertion if widget not found
            return unless item?
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

            if @sort_by?
                firstModel = @_findItemById(models, _.first(@ids))
                lastModel = @_findItemById(models, _.last(@ids))

                # No element so far means that the insertion is straight forward
                if @ids.length == 0
                    @ids.push(model.id)

                # Otherwise, see where in the list we can insert it
                # See if we must insert it before the first model
                else if @compare(model, firstModel) <= 0
                    @ids.unshift(model.id)
                    injectOptions.placement = 'prepend'

                # See if we must insert it after the last model
                else if @compare(model, lastModel) > 0
                    @ids.push(model.id)

                # Otherwise, we're inserting it somewhere in the middle
                # Also, it means that we have at least two elements in
                # @ids (because if there is only one, the element e will
                # either be <= it and be inserted before, or be > it and
                # be inserted after).
                else
                    for i in [0..@ids.length-2]
                        cur_model = @_findItemById(models, @ids[i])
                        next_model = @_findItemById(models, @ids[i + 1])
                        if @compare(cur_model, model) < 0 and
                           @compare(model, next_model) <= 0
                            @ids.splice(i + 1, 0, model.id)
                            # Insert before next_model's DOM element
                            injectOptions.container =
                                @view.$el.find(".item-#{next_model.id}")
                            injectOptions.placement = 'before'
                            break

            Utils.inject(item, injectOptions)
            @updateFirstAndLastDOMClasses()

        getSortByFields: ->
            fields = []
            for field, comparator of @sort_by
                # Make sure field is a string, and get the
                # field part of it (first part).
                field = (""+field).split(' ')[0]
                fields.push(field)
            fields

        deleteItem: (model) =>
            ###
                Deletes a specific item from a list
            ###
            # Erase the ID of the model from the IDs array
            idx = _.indexOf(@ids, model.id)
            @ids.splice(idx, 1)

            # Remove the DOM element
            @view.$el.find(".item-#{model.id}").remove()

            @updateFirstAndLastDOMClasses()

        updateFirstAndLastDOMClasses: ->
            ###
                Make sure the first and the last items of the list have a
                'first' and 'last' class, respectively. This is useful for
                older browser which do not support :first-child and :last-child
                CSS selectors but also for cases where list items might have
                neighbors of other types inside the list wrapper (in a
                hypothetical list subclass scenario)
            ###
            # Only select first-level widgets (which means a list should never
            # have inner wrappers between its view element and its item widgets)
            $items = @view.$el.children('.mozaic-widget')
            # Clear all items of first/last classes first
            $items.removeClass('first').removeClass('last')
            $items.first().addClass('first')
            $items.last().addClass('last')

        getItemWidgetParams: (model, extra_params) =>
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
            name = @item or @mappings?[model.get('object_class')]?.item
            unless name
                logger.error "The list cannot render a model with no specified type."
            return name

        getItemWidgetChannels: (model) ->
            @item_channels or @mappings?[model.get('object_class')]?.item_channels

        itemParamsFromModel: (model, dict = {}) ->
            response = _.extend {}, (@item_params or
                                     @mappings?[model.get('object_class')]?.item_params)
            for key, new_key of dict
                data = model.get(key)
                response[new_key] = data if data
            return response

        extendWidgetParamsFromItem: =>
            ###
                User can send an item_params which is send in as params in items
            ###
            _.extend({}, @widget_params, @item_params) if @item_params?

        getModelsFromChannelData: (item_params) ->
            ###
                Get models from one or more channel events. The default list
                implementation only uses an /items channel to draw its items
                from
            ###
            return item_params.collection?.models or []

        _findItemById: (list, id) ->
            ###
                Find an item from a sorted list, by id
                Note: _.findWhere(list, id: id) can be used once we update to
                Underscore 1.4.4: http://underscorejs.org/#findWhere
            ###
            return _.find(list, (item) -> item.id is id)