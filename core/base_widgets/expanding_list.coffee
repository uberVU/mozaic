define ['cs!widget'], (Widget) ->

    class ExpandingList extends Widget
        ###
            Wrapper for a regular List that loads an extended item to the right
            of it, while compacting the list to the left.

            It is in charge of listening to /filters changes and render a
            corresponding widget next to the list. Besides rendering the widget,
            it should also toggle a .compact class on the List widget, which
            will render it compact (through sole CSS magic---win!)

            The filter is also set from inside it, in order to have as much
            self-contained logic as possible. It will listen to click events
            targeted on the list items directly, thus becoming independent from
            the list or its items (and viceversa)

            Params:
                - filter_key: the name of the filter to be set with the id of
                              the selected item's model.
                - list_widget: the widget name of the list (ideally subclass of
                               the List widget or a List directly)
                - list_params: the params to be sent to the list widget
                - item_widget: the widget name of the extended item
                - item_params: the params to be sent to the extended item widget
                - scroll_channel: enable list scrolling to load more items when
                                  user scroll to the bottom
                - header_widget: the widget name of the list header (optional)
                - header_params: the params to be sent to the header widget

        ###
        subscribed_channels: ['/items', '/filters']

        # Enable state management in order to detect when the list has hit
        # bottom (when an `empty` state was triggered)
        initial_state: 'loading'
        loading_channels: ['/items']

        template_name: 'templates/expanding-list.hjs'

        elements:
            list: '.list'
            listViewport: '.list-viewport'
            itemContainer: '.item-container'

        events:
            'click .list .extend': 'onExpand'
            'click .retract': 'onRetract'

        params_defaults:
            filter_key: (key) -> key or 'id'
            list_widget: (widget) -> widget or 'list'
            list_params: (params) -> params or {}
            item_widget: (widget) -> widget or 'widget'
            item_params: (params) -> params or {}
            header_widget: 'data-params'
            header_params: (params) -> params or {}
            scroll_channel: 'data-params'

        # Gets set to `true` when scrolling is enabled and all items have
        # already been loaded
        reached_bottom: false

        initialize: ->
            @renderLayout(
                list_widget: @list_widget
                list_params: @extendListParams(@list_params)
                header_widget: @header_widget
                header_params: @extendHeaderParams(@header_params)
            , false)

            # Listen to scroll events on the list viewport in the presence of
            # a scrollable list
            @listViewport.on('scroll', @onScroll) if @scroll_channel

        changeState: (state) ->
            super(arguments...)
            # Disable scroll if loaded all items or there weren't any items
            # to begin with
            @reached_bottom = true if state is 'empty'
            # (Re)enable scroll as soon as there seems to be data available,
            # either initially when a channel isn't empty or after a channel
            # reset (like changing a filter)
            @reached_bottom = false if state is 'available'

        get_filters: (params) =>
            itemId = params.model.get(@filter_key)
            unless itemId is @currentItemId
                if itemId then @expand(itemId) else @contract()

            # XXX this doesn't work on page load because the list will not be
            # rendered at this point, we need to find a way to send the active
            # element to the list directly (which means we should wait and
            # render the list only after we receive filters data)
            @updateActiveElement(itemId)

            # Make sure scroll is maintained between list states
            if not @currentItemId and itemId
                @focusOnItem(itemId)
            else if @currentItemId and not itemId
                @focusOnItem(@currentItemId)

            @currentItemId = itemId

        expand: (itemId) ->
            # Mark itself as expanded
            @view.$el.addClass('expanded')
            # Mark list as compacted
            @list.addClass('compact')
            # Inject expanded item
            Utils.inject(@item_widget,
                container: @itemContainer
                params: @getItemParams(itemId)
                placement: 'replace'
            )

        contract: ->
            # Mark itself as normal
            @view.$el.removeClass('expanded')
            # Mark list as normal
            @list.removeClass('compact')
            # Clear any expanded item injected
            @itemContainer.empty()

        updateActiveElement: (itemId) ->
            # Set .active class on selected item (if any)
            @list.find('> li').removeClass('active')
                              .filter(".item-#{itemId}")
                              .addClass('active')

        focusOnItem: (itemId) ->
            item = @list.find(".item-#{itemId}")
            if item.length
                # Get item offset relative to the list
                itemOffset = item.position().top - item.parent().position().top
                @listViewport.scrollTop(itemOffset)

        getItemParams: (itemId) ->
            # Add id to item params and then all channels
            return @extendParams(_.extend({id: itemId}, @item_params))

        extendParams: (params) ->
            ###
                Extend list and list item params with the entire channel list
                received. This way we're cleaning up the passing of channels
                through all this list-related widgets: the union of all the
                channels needed for the expanded list, the list iteself and its
                items should be put together and sent to all of them from one
                place only. The overhead of passing possibly irrelevant
                channels is insignificant.
            ###
            return _.extend({channels: @params.channels}, params)

        extendHeaderParams: (params) ->
            ###
                Provide extended parameters for the header widget.
            ###
            return @extendParams(params)

        extendListParams: (params) ->
            ###
                Provide extended parameters for the list widget.

                When a list is embedded within the expanded list, the expanded
                is managing the scroll interactions with that list, not the
                list itself. This also means that we cannot have
                minimize_dom_nodes set to true, because the core list needs
                to manage its own scroll in order to have that.
            ###
            intermediate_params = @extendParams(params)
            return _.extend(intermediate_params, {
                enable_scroll: false
                minimize_dom_nodes: false
            })

        onExpand: (e) =>
            item = @getItemFromEvent(e)

            # Deny any events from child links or buttons
            if e.target isnt e.currentTarget
                buttonTags = ['a', 'button']
                # If the clicked target itself is a button
                return if e.target.nodeType in buttonTags
                # If the clicked target is inside a button and that buttons is
                # a child of the item
                for tag in buttonTags
                    if $(e.target).closest(tag).length
                        return if item.has($(e.target).closest(tag)).length

            e.preventDefault()

            # Make sure user is not trying to select something, which case we
            # should disable the expanding
            return if getSelection()?.toString()

            filter_changes = @getFilterChangesForExpand(item)
            @modifyChannel('/filters', filter_changes)

        getFilterChangesForExpand: (item) ->
            ###
                Filter changes for the case of item expansion.

                By default, it only includes the id of the item, but feel
                free to override this in your inherited class in order to
                provide custom URL parameters.
            ###
            filterChange = {}
            filterChange[@filter_key] = item.data('id')
            return filterChange

        onRetract: (e) =>
            e.preventDefault()

            @modifyChannel('/filters',
                           @getFilterChangesForRetract(),
                           {update_mode: 'exclude'})

        getFilterChangesForRetract: ->
            ###
                Filter changes for the case of item retraction.

                By default, we only clean up the item id, but please feel free
                to do some more clean-up in your inherited class in order
                to match the keys you're publishing to filters in
                getFilterChangesForExpand.
            ###
            filterChange = {}
            filterChange[@filter_key] = null
            return filterChange

        onScroll: (e) =>
            ###
                In the case of scrollable lists (a list that needs to "load
                more" once the users scroll to its bottom side), check when
                the users comes very close to bottom part of the list and
                scroll the list channel
            ###
            top = @listViewport.scrollTop()
            dif = @list.outerHeight() - @listViewport.outerHeight() - top

            @scrollList() if dif < 5

        scrollList: ->
            ###
                Scroll list channel until it reaches bottom (no new items were
                returned by the last refresh)
            ###
            @scrollChannel('/items') unless @reached_bottom

        getItemFromEvent: (e) ->
            target = $(e.currentTarget)
            return target if target.hasClass('list-item')
            return target.closest('.list-item')

        destroy: =>
            @listViewport.off('scroll', @onScroll)
            super()
