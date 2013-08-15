define [], () ->

    class ListPostProcessMixin

        postProcessListItems: ->
            ###
                Post-process the list items. It has 2 purposes:
                * add a special class to the first and last item in the list
                * optionally separate items by page breaks
            ###
            @_updateFirstAndLastDOMClasses()
            if @insert_page_breaks
                @_insertPageBreaks()
            @_updateListItemsVisibility()

        _updateFirstAndLastDOMClasses: ->
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

        _pageBreak: ->
            ###
                Returns the HTML representation of a page break to be inserted
                between list elements. We make sure that for HTML consistency
                this element is of the same type as the widgets.
            ###
            return "<#{@item_element} class='#{Constants.PAGE_BREAK_CLASS}'>"+
                   "</#{@item_element}>"

        _insertPageBreaks: ->
            ###
                Make sure that before and after each item there is a page
                break to be used in pagination algorithms.
            ###
            items = @view.$el.children('.mozaic-widget')
            for item in items
                prev = $(item).prev()
                if not prev.hasClass(Constants.PAGE_BREAK_CLASS)
                    $(item).before(@_pageBreak())
                next = $(item).next()
                if not next.hasClass(Constants.PAGE_BREAK_CLASS)
                    $(item).after(@_pageBreak())

        _updateListItemsVisibility: ->
            ###
                We are keeping in DOM only the items positioned
                close to viewport
            ###
            return if @isDetachedFromDOM
            return unless @minimize_dom_nodes

            for list_item, item_index in @list_items
                @_manageItemTransitionIntoAndOutOfViewport(list_item, item_index)

        _manageItemTransitionIntoAndOutOfViewport: (list_item, list_item_index) ->
            ###
                The items that are not close to viewport need to be removed
                from DOM. This will help reduce the number of DOM elements
                in page.
            ###
            return if @isDetachedFromDOM

            dom_item = @view.$el.find(".item-#{list_item.id}")

            if list_item_index > 15
                in_viewport = Utils.checkCloseToViewport(dom_item, @scroll_element)
            else
                # We won't touch the first page of items
                # This is important for those situations when you are at the
                # bottom of the list and you need to scroll to the top to see
                # new items. Keeping the first page always visible will help in
                # this scenario.
                #
                # ALSO, why are we hardcoding 15 in here? Because at a 'reset'
                # event, there is no easy way of figuring out the widget height
                # just yet - they haven't been rendered! Thus, we approximate
                # that at most 15 widgets will be visible into the first
                # viewport.
                in_viewport = true

            # Item was not previously visible and it just became visible.
            # Take out the DELAY_WIDGET attribute, which will provoke a
            # dom mutation, causing the widget starter to actually start
            # the widget.
            if (not list_item.visible) and in_viewport
                list_item.visible = true
                dom_item.removeAttr(Constants.DELAY_WIDGET)
                return

            # Item was visible and it's not anymore. We remove it from
            # the DOM and place it in the exact same place with DELAY_WIDGET
            # attribute on, and a fixed height to emulate the phantom
            # of the original widget.
            if list_item.visible and (not in_viewport)
                list_item.visible = false

                # Every item in a list widget with minimize_dom_nodes: true
                # will be wrapped in a dom element that will always keep the
                # space allocated for the widget even after it is
                # removed from DOM
                dom_item_wrapper = dom_item.parent()
                dom_item_wrapper.css(
                    height: dom_item_wrapper.height()
                )

                model_to_insert = list_item.model
                # The item will be inserted again in DOM that's why we are
                # removing it from @list_items
                @_removeItemFromListItems(list_item)
                all_models = (list_item.model for list_item in @list_items)
                options =
                    override_inject_options:
                        placement: 'replace'
                        container: dom_item_wrapper
                        type: 'div'
                        # The wrapper has already been injected
                        wrappedInject: false

                @insertItem(model_to_insert, all_models, options)

        _removeItemFromListItems: (list_item) ->
            idx = _.indexOf(@list_items, list_item)
            @list_items.splice(idx, 1)
