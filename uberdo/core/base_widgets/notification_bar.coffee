define ['cs!widget'], (Widget) ->

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

        initialize: =>
            @renderLayout
                type: @type
                message: @message

            # Loading and status notifications stay visible for an indefinite
            # period of time
            if @type not in ['loading', 'status']
                @timeout = setTimeout(@close, 5000)

            # Appear gracefully
            @view.$el.css(opacity: 0).animate(opacity: 1)

        close: (e) =>
            e.preventDefault() if e?

            # Fade out and die
            @view?.$el.animate({opacity: 0}, -> $(this).remove())
