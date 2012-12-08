define ['cs!scrollable_widget'], (ScrollableWidget) ->

    class WidgetList extends ScrollableWidget
        ###
            Generic Widget: receives a collection and injects
            a list of widgets. This handles common operations like
            add/remove and also has filtering/sorting support.
        ###
        subscribed_channels: ['/items']
        loading_channels: ['/items']

        template_name : 'templates/list.hjs'

        params_defaults:
            enable_scroll: 'data-params'
            className: 'data-params'
            item: 'data-params'
            item_channels: 'data-params'
            item_params: 'data-params'
            # Used to specify what fields to dynamically extract
            # from model. Should look like {key1: new_key1, key2: new_key2, ..}
            # where key is the one in model, and new_key is the one will be used
            # as key.
            item_model_params: 'data-params'
            filter_by: 'data-params'
            sort_by: 'data-params'
            container: 'data-params'
            item_element: 'data-params'
            prepend: 'data-params'
            # This mappings params is used to be able
            # to insert different widgets (with different
            # models).
            mappings: 'data-params'
            first_class: 'data-params'
            last_class: 'data-params'

        # A list of comparators for list. You can also push to
        # this list and define your own comparator in your type
        # of list.
        _comparators_map:
            str:  'strComparator'
            int:  'intComparator'
            date: 'dateComparator'

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
                @scrollable_channels = ['/items']

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

            # Initialize first_class and last_class
            if not @first_class?
                @first_class = 'first'
            if not @last_class?
                @last_class = 'last'

            super()

        changeState: (state, item_params) ->
            super(state, item_params)
            if state == 'empty'
                # TODO: Add `end` state to widget base
                if not item_params.collection.length
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

        strComparator: (a, b) ->
            a = _.str.trim (a).toLowerCase()
            b = _.str.trim (b).toLowerCase()
            return -1 if a < b
            return 1 if a > b
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

            if item_params.type == 'reset' and not @isChannelDataEmpty(item_params)
                # Render layout with "available" state flag
                @renderLayout {state: 'available'}
                @ids = []
                # Insert each item one by one
                item_params.collection.each( (model) =>
                    if @matchesFilters(model)
                        @insertItem(model, item_params.collection)
                )

            # Add a new item to a list by injecting a widget to the end of it
            else if item_params.type == 'add'
                # Clear template blank state if previous state was "empty"
                # and no _reset_ event has been triggered in the meantime
                if @data_state == 'empty'
                    @renderLayout {state: 'available'}
                unless item_params.model.id?
                    item_params.model.set('id', Utils.guid('new'))
                if @matchesFilters(item_params.model)
                    @insertItem(item_params.model, item_params.collection)

            # If the event is `change_attribute`, check if the model matches the
            # filters and decide whether to add it or not
            else if item_params.type == 'change_attribute'
                if @matchesFilters(item_params.model)
                    # If we have a change in one of the sort_by attributes, we
                    # need to remove this item and add it again, to go through
                    # all the insert-in-sorted-place logic. And will be added
                    # by the right below code again.
                    if item_params.attribute in @getSortByFields()
                        @deleteItem(item_params.model, item_params.collection)
                    # Don't create duplicates and add it only if it is unique
                    if @el.find(".item-#{item_params.model.id}").length == 0
                        @insertItem(item_params.model, item_params.collection)

            # Delete a specific item from a list
            else if item_params.type == 'remove'
                if @matchesFilters(item_params.model)
                    @deleteItem(item_params.model, item_params.collection)

        insertItem: (model, collection, options = {}) =>
            ###
                @param {Object} options
                @param {Boolean} [options.isLoadedLater] - mark the item as being
                                                        loaded after view refresh
            ###
            _.defaults options,
                 isLoadedLater: false

            @removeFirstAndLastCSS(collection)
            @_insertItem(model, collection, options)
            @addFirstAndLastCSS(collection)

        _insertItem: (model, collection, options) =>
            # Find the name of the widget to insert.
            item = @getItemWidgetName model
            # Skip the insertion if widget not found
            return unless item?
            # Extra params of the widget.
            extra_params = _.pick(options, 'isLoadedLater')
            item_widget_params = @getItemWidgetParams model, collection, extra_params

            # Also add a class to uniquely identify the item
            # Needed when deleting the item from the list
            class_name = if !@className then "item-#{model.id}" else "#{@className} item-#{model.id}"

            if @sort_by?
                # No element so far means that the insertion is straight forward
                if @ids.length == 0
                    Utils.injectWidget(@el, item, item_widget_params, class_name, null, @item_element ? 'li')
                    @ids.push(model.id)
                    return

                # Otherwise, see where in the list we can insert it
                # See if we must insert it before the first model
                first_model_so_far = collection.get(_.first(@ids))
                if @compare(model, first_model_so_far) <= 0
                    Utils.injectWidget(@el, item, item_widget_params, class_name, null, @item_element ? 'li', false, true)
                    @ids.unshift(model.id)
                    return

                # See if we must insert it after the last model
                last_model_so_far = collection.get(_.last(@ids))
                if @compare(model, last_model_so_far) > 0
                    Utils.injectWidget(@el, item, item_widget_params, class_name, null, @item_element ? 'li')
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
                        @ids.splice(i + 1, 0, model.id)
                        dom_element = @el.find(".item-#{next_model.id}")
                        # Insert before next_model's DOM element
                        Utils.injectWidget(dom_element, item, item_widget_params, class_name, null, @item_element ? 'li', false, @prepend, true)
                        return
            else
                Utils.injectWidget(@el, item, item_widget_params, class_name, null, @item_element ? 'li', false, @prepend)

        getSortByFields: ->
            fields = []
            for field, comparator of @sort_by
                # Make sure field is a string, and get the
                # field part of it (first part).
                field = (""+field).split(' ')[0]
                fields.push(field)
            fields

        deleteItem: (model, collection) =>
            @removeFirstAndLastCSS(collection)
            @_deleteItem(model, collection)
            @addFirstAndLastCSS(collection)

        _deleteItem: (model, collection) =>
            ###
                Deletes a specific item from a list
            ###
            # Erase the ID of the model from the IDs array
            idx = _.indexOf(@ids, model.id)
            @ids.splice(idx, 1)

            # Remove the DOM element
            @el.find(".item-#{model.id}").remove()

        addFirstAndLastCSS: (collection) =>
            ###
                Add CSS classes to the first and last items in the collection.

                In order to find out which are the first and last items,
                we will use @ids, which contains the current sorted state
                of the models.
            ###
            if @ids.length == 0
                return
            first_id = @ids[0]
            last_id = @ids[@ids.length - 1]
            @el.find(".item-#{first_id}").addClass(@first_class)
            @el.find(".item-#{last_id}").addClass(@last_class)

        removeFirstAndLastCSS: (collection) =>
            ###
                Remove first and last CSS classes to items in the collectoin.

                In order to find out which are the first and last items,
                we will use @ids, which contains the current sorted state
                of the models.
            ###
            if @ids.length == 0
                return
            first_id = @ids[0]
            last_id = @ids[@ids.length - 1]
            @el.find(".item-#{first_id}").removeClass(@first_class)
            @el.find(".item-#{last_id}").removeClass(@last_class)

        getItemWidgetParams: (model, collection, extra_params) =>
            ###
                Method returns the params of the item widget which will be inserted as part of the current list.
                Can be overridden in specialiazed list classes to provide custom params to list items.
                @param {Object} model Backbone.Model instance of the item to be inserted
                @param {Object} collection Backbone.Collection instance of all the items in the list
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

    return WidgetList
