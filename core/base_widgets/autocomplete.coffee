define ['cs!widget'], (Widget) ->

    class AutocompleteWidget extends Widget

        elements:
            input: 'input.search-box'
            list: 'ul.results'
            items: 'ul.results li'

        events:
            'keydown @input': 'onKeyDown'
            'keyup @input': 'onKeyUp'
            'mouseenter @items': 'onMouseEnter'
            'click @items': 'onItemClick'
        limit: 8
        activeClass: 'active'

        setup: () ->
            ###
                Setup method, has to be run internally,
                after layout render
            ###
            # Init empty query if not already defined
            @query = @query or ''

            # Assign previous value to input (if any)
            @input.val(@query)

            # Create initial reults selection, as all items
            @results = @items

            # Implicitly hightlight first result
            @highlight @results.first()

        onKeyDown: (e) =>
            ###
                Event handler for input key down
            ###
            switch e.keyCode
                when 13
                    # ENTER
                    e.preventDefault()
                when 27
                    # ESCAPE
                    e.preventDefault()
                when 38
                    # UP
                    @prev()
                    e.preventDefault()
                when 40
                    # DOWN
                    @next()
                    e.preventDefault()

            e.stopPropagation()

        onKeyUp: (e) =>
            ###
                Event handler for input key up
            ###
            switch e.keyCode
                when 13
                    # ENTER
                    @select @active

                when 27
                    # ESCAPE
                    @close()
                else
                    # Uncaught key, filter results
                    # if query changed.
                    if @query != (@query = @input.val())
                        @filter()

            e.preventDefault()
            e.stopPropagation()

        onMouseEnter: (e) =>
            ###
                Event handler for list hover
            ###
            @highlight $(e.currentTarget), true

        onItemClick: (e) =>
            ###
                Event handler for list item click
            ###
            @select $ e.currentTarget
            false

        open: () ->
            ###
                Open results
                Extend and call in subclass per needs.
            ###

        close: () ->
            ###
                Close results
                Extend and call in subclass per needs.
            ###
            @input.val @query = ''

        filter: () ->
            ###
                Filter available options with user input
            ###
            # Filter loose matches
            @results = @items.filter((i, item) => @match(item))

            # Sort results
            @results.sort (a, b) => @sort a, b

            # Limit matches
            @results = @results.slice 0, @limit if @limit

            # Physically arrange sorted selection
            @results.each (i, item) =>
                @list.append item

            # Show matches
            @items.hide().filter(@results).show()

            # Make first remaining element active
            @highlight if @results.length then @results.first() else $()

            # Update widget's tiny scrollbar
            Utils.renderScrollbar(@el.find('.tiny_scrollbar'))

        sort: (a, b, element = true) ->
            ###
                Sort between items
            ###

            # Make sure the all_items elem is always first
            # The all_items 'li' must have option='all' for the sorting to work
            if element
                if a.getAttribute('option') is 'all' or
                    $(a).data('value') is '' then return -1
                if b.getAttribute('option') is 'all' or
                    $(b).data('value') is '' then return 1

            # Fetch values
            aValue = if element then $(a).text() else a
            bValue = if element then $(b).text() else b

            # Prioritize strict matches
            aStrict = @compare aValue, true
            bStrict = @compare bValue, true

            return -1 if aStrict and not bStrict
            return +1 if bStrict and not aStrict

            # Then loose matches
            aLoose = @compare aValue, false
            bLoose = @compare bValue, false

            return -1 if aLoose and not bLoose
            return +1 if bLoose and not aLoose

            # Fallback alphabetically
            return -1 if aValue < bValue
            return +1 if aValue > bValue

            # Draw
            0

        match: (item, strict = false) ->
            ###
                Match function
            ###

            # Hide default value when query is not empty
            if @query and not $(item).data 'value'
                return false

            # Create keywords array
            # Need to convert to String because boolean and numeric
            # values are evaluated to their respective types, in which
            # case split() breaks.
            keywords = (String($(item).data('keywords')) or '').split()

            # Add value and text to keyword array
            keywords.push String($(item).data('value')) or ''
            keywords.push $(item).text()

            # Search for matches in all keywords
            for keyword in keywords
                return true if keyword and @compare keyword, strict
            false

        compare: (value, strict) ->
            ###
                String compare function
                Searches value within query.
            ###
            if strict
                return value.toLowerCase().indexOf(@query.toLowerCase()) == 0
            else
                return ~value.toLowerCase().indexOf(@query.toLowerCase())

        highlight: (element) ->
            ###
                Make element active
                Caution when extending, function must
                return active element.
            ###
            @active = element

            # Add CSS class (also returns @active element)
            @items.removeClass(@activeClass).filter(@active).addClass @activeClass

        prev: () ->
            ###
                Highlight previous element
            ###
            if not (@highlight @active.prev ':visible').length
                @highlight @results.last()

        next: () ->
            ###
                Highlight previous element
            ###
            if not (@highlight @active.next ':visible').length
                @highlight @results.first()

        select: (element) ->
            ###
                Select element
                Extend in subclass per needs.
            ###
            # Close results
            @close()

    return AutocompleteWidget
