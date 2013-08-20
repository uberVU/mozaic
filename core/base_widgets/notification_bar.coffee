define ['cs!widget'], (Widget) ->

    # Minimum duration of time for a notification to stay visible
    MIN_DURATION = 5
    # Seconds to add per each letter
    DURATION_PER_LETTER = 0.25

    class NotificationBarWidget extends Widget
        ###
            Notification bar unit, can be destroyed by parent notifications
            widget or can destroy itself if close button is made visible for
            current type of notification.

            Closes automatically for any type of notification that isn't
            _status_ nor _loading_.
        ###
        template_name: 'templates/notification_bar.hjs'

        params_defaults:
            type: 'data-params'
            message: 'data-params'

        events:
           'click a.close': 'close'
           # Prevent any notification from disappearing while hovering over it
           'mouseover .bar': 'cancelNotificationTimeout'
           'mouseout .bar': 'startNotificationTimeout'

        initialize: =>
            @renderLayout
                type: @type
                message: @message

            # Appear gracefully
            @view.$el.css(opacity: 0).animate(opacity: 1)
            @startNotificationTimeout()

        close: (e) =>
            e.preventDefault() if e?

            # Fade out and die
            @view?.$el.animate({opacity: 0}, -> $(this).remove())

        startNotificationTimeout: =>
            # Loading and Status notifications stay visible for an indefinite
            # period of time, the others should fade out a variable (based on
            # the length of their message) amount of time
            if @type not in ['loading', 'status']
                @timeout = setTimeout(@close,
                    @getDurationBasedOnMessageLength(@message))

        cancelNotificationTimeout: =>
            # Stop notification timeout that already initiated, in order to
            # hold any notification visible for an indefinite period of time
            if @timeout?
                clearTimeout(@timeout)
                @timeout = null

        getDurationBasedOnMessageLength: (text) ->
            ###
                The amount of time (in ms) a notification should remain
                visible, based on the length of its message
            ###
            return Math.max(MIN_DURATION, text.length * DURATION_PER_LETTER) * 1000
