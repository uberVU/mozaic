define ['cs!widget'], (Widget) ->
    class ScrollableWidget extends Widget
        ###
            Widget which supports scrolling a given data channel.

            It is meant to display a list that supports scroll-down
            on a list of items with fetch from the server
        ###
        params_defaults:
            scroll_target: (scroll_target) -> if scroll_target == 'widget' then 'widget' else 'window'

        destroy: =>
            super()
            @scroll_element = null
            if @scrollable_channels
                @unwireScrollEvent()

        changeState: (state, params...) ->
            super(state, params...)
            if state isnt 'empty'
                @enableScroll() if not @disable_scroll
            else if @scroll_enabled
                @disableScroll()

        initialize: ->
            @scroll_enabled = true

            # Decide which element is used for hooking the scroll event on.
            # This is important, because we can have two types of scroll:
            # - a window scroll, so the scrollbar is at window level
            # - the div scroll, when we have a div with a max-height lower
            #   than the the viewport's height (what you can see in browser),
            #   in which case the scroll will be triggered on the div itself.
            @scroll_element = (if @scroll_target == 'widget' then @view.el else window)

            if @scrollable_channels
                @wireScrollEvent()

        wireScrollEvent: ->
            ###
                Detects when the scroll is on the bottom of the page
                and triggers the scroll event based on the channels the
                widget is listening
            ###
            $(@scroll_element).on('scroll', @onScroll)

        unwireScrollEvent: ->
            ###
                Unwire the scroll event for detecting whether bottom of the
                page was hit.
            ###
            $(@scroll_element).off('scroll', @onScroll)

        onScroll: (e) =>
            e.preventDefault()
            e.stopPropagation()

            if @scroll_target == 'window'
                height_to_scroll = $(document).height() - $(window).height()
            else if @scroll_target == 'widget'
                height_to_scroll = @scroll_element.scrollHeight -
                                   $(@scroll_element).height()

            # Check if we've reached the bottom of how much we can scroll in
            # the container.
            dif = $(@scroll_element).scrollTop() - height_to_scroll
            if Math.abs(dif) < 5 and height_to_scroll > 5
                @scrollDown()

        scrollDown: =>
            ###
                There is no need to disable scroll in this method because
                now it is wrapped by _.debounce.
            ###
            if not @scroll_enabled
                return

            # Don't let this user scroll too often. Useful for
            # browsers like FF/Linux which are very sensible when it comes
            # to triggering the scroll event.
            if @last_scroll? and new Date().getTime() - @last_scroll <= 1000
                return

            @last_scroll = new Date().getTime()
            for channel in @scrollable_channels
                @scrollChannel(channel)

        disableScroll: =>
            ###
                Temporarily disable scroll for this widget so that we don't
                perform scroll too often.
            ###
            @scroll_enabled = false

        enableScroll: =>
            ###
                Re-enable scroll for this widget.
            ###
            @scroll_enabled = true

        startBeingDetached: =>
            @disableScroll()
            super()

    return ScrollableWidget
