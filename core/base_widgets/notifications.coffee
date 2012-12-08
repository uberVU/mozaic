define ['cs!widget'], (Widget) ->

    class NotificationWidget extends Widget
        ###
            Pubsub-controlled widget for displaying notifications on page.
            Doesn't use regular datasource channels so it can be called
            from any place. (not only widgets subscribed to a certain channel)

            The /notifications pubsub channel only receives two paramters,
            _type_ and _message_, both strings.
        ###
        loadingWidgets: 0

        initialize: =>
            # Subscribe to all notifications
            pipe = loader.get_module('pubsub')
            pipe.subscribe('/notifications', @get_notifications)

        get_notifications: (params) =>
            # Remove ALL notifications
            if params.type is 'clear_all'
                @removeNotification(@view.$el.children())
                return

            # Use empty messages to clear notifications
            if not params.message
                # Loading notifications stack up so we only remove one when
                # the loading count has been brought back down to 0
                if params.type is 'loading'
                    @loadingWidgets-- if @loadingWidgets > 0
                    return if @loadingWidgets

                @removeNotification(@view.$el.children(".#{params.type}"))
                return

            # Inject a loading notification only if another is not already
            # present, otherwise just increase the loading count
            if params.type is 'loading'
                return if ++@loadingWidgets > 1

            @injectNotification(params)

        injectNotification: (params) =>
            # Avoid duplicates
            duplicate = false
            @view.$el.children(".#{params.type}").each ->
                # We extract the message from the initial data-params because
                # the bar template might not be rendered yet
                notificationParams = $(this).data('params')
                if notificationParams.message is params.message
                    duplicate = true
                    # In case that duplicate was just fading away, make sure it
                    # doesn't. Only for status or loading message
                    if notificationParams.type in ['status', 'loading']
                        $(this).stop().animate(opacity: 1)

            if not duplicate
                Utils.injectWidget(@view.$el, 'notification_bar', params, params.type)

        removeNotification: ($selector) =>
            $selector.animate({opacity: 0}, -> $(this).remove())
