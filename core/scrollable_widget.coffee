define ['cs!widget'], (Widget) ->
    class ScrollableWidget extends Widget
        scroll_enabled: true

        constructor: (params) ->
            super(params)
            if @scrollable_channels
                @wireScrollEvent()

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

        scrollDown: =>
            # Don't do anything if scroll is not enabled
            if not @scroll_enabled
                return

            $(".loading").show()
            translated = (@channel_mapping[channel] for channel in @scrollable_channels)
            pipe = loader.get_module('pubsub')
            pipe.publish('/scroll', translated)
            # Temporarily disable scroll until new data arrives
            # Useful when scrolling event can be trigger multiple times before
            # data fetch
            @disableScroll()

        disableScroll: =>
            ###
                Temporarily disable scroll for this widget.
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
