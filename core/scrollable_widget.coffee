define ['cs!widget'], (Widget) ->
    class ScrollableWidget extends Widget
        ###
            Widget which supports scrolling a given data channel.

            It is meant to display a list that supports scroll-down
            on a list of items with fetch from the server
        ###
        scroll_enabled: true

        constructor: (params) ->
            super(params)
            if @scrollable_channels
                @wireScrollEvent()

        changeState: (state, params...) ->
            super(state, params...)
            if state isnt 'empty'
                @enableScroll() if not @disable_scroll
            else if @scroll_enabled
                @disableScroll()

        wireScrollEvent: ->
            ###
                Detects when the scroll is on the bottom of the page
                and triggers the scroll event based on the channels the
                widget is listening
            ###
            $(window).scroll(@onScroll)

        onScroll: =>
            dif = $(window).scrollTop() - $(document).height() + $(window).height()
            if Math.abs(dif) < 5
                @scrollDown()
            return false

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
