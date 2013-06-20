define ['cs!mozaic_module'], (Module) ->
    class LoadingAnimation extends Module

        MAX_SUCCESS_RENDER_ROUNDS: 10
        LOADING_FINISHED_CHECK_INTERVAL: 100 #ms
        # List widget is allowed here as the ones with empty data will not be rendered
        ALLOWED_TO_BE_NASTY: [
            'top_locations_filter', 'current_location', 'new_items',
            'item_count', 'stream_info', 'custom_sources_info',
            'custom_source_item', 'custom_sources_list', 'list',
            'signals_count', 'mentions', 'signals']
        INTERVAL_FOR_99_PERCENT: 10 # seconds
        ACCELERATED_FINISH: 1.5 # seconds at most to finish after we had a lucky streak
        REPORT_NASTY_WIDGETS_INTERVAL: 25 # seconds

        new_widgets: []
        rendered_widgets: []
        success_render_rounds: 0
        id_to_name: {}
        start_time: 0

        constructor: ->
            super()
            @updateLoadingMessage()

        initialize: =>
            ###
                When the loading animation module is first initialized,
                it subscribes itself to widget events such as
                "widget initialized" and "widget rendered", and starts checking
                periodically what's in the difference of these two sets.
            ###
            @pipe = loader.get_module('pubsub')
            @pipe.subscribe('/new_widget', @newWidgetAppeared)
            @pipe.subscribe('/new_widget_rendered', @newWidgetRendered)
            @start_time = new Date().getTime()
            @intervalHandle = setInterval(@checkIfLoadingFinished, @LOADING_FINISHED_CHECK_INTERVAL)
            # Mark the entire application as "loading"
            App.isLoading = true

        # If the admin changed the group, personalize
        # loading message.
        updateLoadingMessage: =>
            if window.location.href.indexOf('print') != -1
                $('.loading-text').append(' Generating preview...')
            else if window.location.href.indexOf('group_id') != -1
                $('.loading-text').append(' Changing view...')

        newWidgetAppeared: (message) =>
            ###
                This callback is performed whenever a new widget has appeared
                in the system. Widgets are initialized by the widget starter
                whenever all their channels have been initialized, and after
                they have been injected into the DOM.

                We store both the widget ID and a mapping from ID to name
                to use later without needing to break encapsulation and
                hack into loader's internal structures to get the widget name.
            ###
            id = message.widget.params['widget_id']
            name = message.widget.params['name']
            @new_widgets.push(id)
            @id_to_name[id] = name

        newWidgetRendered: (id) =>
            ###
                This callback is performed whenever a widget is rendered for
                the first time. Widgets publish this kind of event automatically
                when they do renderLayout() for the first time. The single
                exception to this are widgets without a template_name, who
                are considered "container" widgets whose sole role is to
                insert other widgets into the DOM.
            ###
            @rendered_widgets.push(id)

        checkIfLoadingFinished: =>
            ###
                This function is called periodically to check if loading has
                finished. It compares the list of newly appeared widgets
                with the list of rendered widgets and decides that it's ready
                when the difference contains only "allowed" widgets.
            ###

            @updateProgressBar()
            current_time = new Date().getTime()
            nasty_widgets_time = (current_time - @start_time > 1000 * @REPORT_NASTY_WIDGETS_INTERVAL)

            # Check if there are still nasty widgets, and if there are
            # rest the counter of consecutive iterations without nasty widgets.
            #
            # Also, if enough time has passed since the loading started,
            # report the "nasty" widgets for debugging purposes.
            nasty = @getNastyWidgets()
            if nasty.length > 0
                @success_render_rounds = 0
                current_time = new Date().getTime()
                if nasty_widgets_time
                    @reportNastyWidgets()
                return

            # Don't allow any more nasty widgets on production.'
            # Just log them with critical, but try to deliver a partial
            # user experience as opposed to a completely broken one. (#739)
            if nasty_widgets_time and App.general.environment == 'production'
                @finishLoadingAnimation()

            # If we reached this point, it means that there haven't been
            # nasty widgets for success_render_rounds + 1 consecutive
            # iterations.
            @success_render_rounds = @success_render_rounds + 1

            # Store the first moment in time when we have had a good "streak"
            # of widgets. Since this moment on, we consider that loading has
            # finished and our job is just to get the progress bar quickly
            # to the end.
            if @success_render_rounds >= @MAX_SUCCESS_RENDER_ROUNDS and not @momentLoadingFinished
                @momentLoadingFinished = new Date().getTime()

            # If we have had a "good streak" without nasty widgets,
            # then hide the loading animation.
            if @momentLoadingFinished and @getProgress() >= 99
                @finishLoadingAnimation()

        finishLoadingAnimation: =>
            ###
                Hide the loading animation and stop polling for nasty widgets.
            ###
            $('#loading-animation').hide()
            clearInterval(@intervalHandle)
            # Update the global "loading" flag from the application once the
            # loading is done
            App.isLoading = false
            @pipe.publish('/loading_animation_finished')

        getNastyWidgets: =>
            ###
                Get the list of nasty widgets.

                These are widgets which have announced themselves as
                being initialized, but have not performed renderLayout().
                Notable exceptions to this rule are specified in
                ALLOWED_TO_BE_NASTY.
            ###
            candidates = _.difference(@new_widgets, @rendered_widgets)
            nasty_widgets = []
            for id in candidates
                name = @id_to_name[id]
                unless name in @ALLOWED_TO_BE_NASTY
                    nasty_widgets.push(id)
            nasty_widgets

        reportNastyWidgets: =>
            ###
                Reports the current list of nasty widgets.

                For debugging purposes only.
            ###
            @iterations = if @iterations then @iterations + 1 else 1
            nasty = @getNastyWidgets()

            # Make sure we display the nasty widgets the first time we
            # try to report them. This is because on production we will
            # NOT keep an infinite loading to prevent a completely broken
            # user experience.
            if @iterations % 20 == 1
                names = (id + "(" + @id_to_name[id] + ")" for id in nasty)
                logger.error('Nasty widgets: ' + names)

        getProgress: =>
            ###
                Get the current percentage of progress.

                Since we cannot estimate how many widgets there will be
                in the page, we will simply scale it linearly to a few seconds.
                This number of seconds is stored in INTERVAL_FOR_99_PERCENT.

                After this linear interval has passed, loading gets stuck
                at 99%, hoping that it won't take much longer to load :)
            ###

            # Compute the linear progress so far. We go from 0% to 99% linearly
            # in INTERVAL_FOR_99_PERCENT seconds.
            current_time = new Date().getTime()
            millis = @INTERVAL_FOR_99_PERCENT * 1000.0
            difference = Math.min(current_time - @start_time, millis)
            linear_progress = difference / millis * 99

            # If loading has finished although, we accelerate the
            # progress so that we finish the progress bar in at most 1 second.
            if @momentLoadingFinished
                difference2 = Math.min(current_time - @momentLoadingFinished, 1000)
                millis2 = @ACCELERATED_FINISH * 1000.0
                accelerated_progress = difference2 / millis2 * 100
                return Math.max(accelerated_progress, linear_progress)

            return linear_progress

        updateProgressBar: =>
            ###
                Update the progress bar animation.
            ###
            progress = @getProgress()
            $('#loading-animation .progress .bar').css("width", "#{progress}%")
