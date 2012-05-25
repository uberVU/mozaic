define ['cs!widget'], (Widget) -> 
    class ScrollableWidget extends Widget
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
            $(window).scroll( =>
                dif = $(window).scrollTop() - $(document).height() + $(window).height()
                if Math.abs(dif) < 5
                    @scroll()
            )

        scroll: =>
            $(".loading").show()
            translated = (@channel_mapping[channel] for channel in @scrollable_channels)
            pipe = loader.get_module('pubsub')
            pipe.publish('/scroll', translated)

    return ScrollableWidget