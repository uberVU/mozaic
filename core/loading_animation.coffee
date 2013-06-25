define ['cs!mozaic_module'], (Module) ->
    class LoadingAnimation extends Module
        ###
            A graceful way to preload the app widgets, having a "loading"
            screen that waits until widgets are being loaded in the back,
            thus assuming that the widgets are not to be shown while loading
            TODO: Should ignore widgets that have own loading states, they
            don't need a global screen to cater for them

            It subscribes to the /new_widget and /new_widget_rendered pubsub
            channels, in order to track each created and rendered widget,
            respectively.

            On an interval of LOADING_FINISHED_CHECK_INTERVAL, it repeatedly
            checks what's the current loading progress of the entire app, based
            on a (highly) estimative logic:
                - With each interval iteration, the list of widgets that have
                been triggered as created, but not yet rendered, are collected.
                They are called "nasty widgets"
                - Whenever an interation happens with zero nasty widgets, it is
                considered a "success round"
                - We expect MAX_SUCCESS_RENDER_ROUNDS **consecutive** success
                rounds to happen before considering the app loaded and hiding
                the loading animation. This translates to: we keep the loading
                animation visible until at some point in time no widgets are
                pending to load for a LOADING_FINISHED_CHECK_INTERVAL *
                MAX_SUCCESS_RENDER_ROUNDS period of time (half a second with
                the current configuration)
                - In contrast, if a round with nasty widgets happens after
                more than REPORT_NASTY_WIDGETS_INTERVAL seconds of total
                loading, the current nasty widgets will be reported using error
                logging, and in production the loading animation will be
                forcibly removed. The last part translates to: The loading
                animation can't take more than REPORT_NASTY_WIDGETS_INTERVAL
                seconds in production (25 seconds in current configuration)

            The formula for displaying the loading progress is just as
            unpredictible:
                - It estimates that 99% of the loading will take
                INTERVAL_FOR_99_PERCENT seconds (6 seconds in current
                configuration). So it loads linearly up to this point
                - If it takes more than INTERVAL_FOR_99_PERCENT seconds, it
                will be locked at 99% until the previous logic considers the
                app to be loaded
                - If the loading is flagged as done before
                INTERVAL_FOR_99_PERCENT seconds have passed, the progress bar
                is accelerated to 100% in order to feel natural (even though
                the app is ready at this point). This fake loading compensation
                can only take up to ACCELERATED_FINISH seconds, though (0.2
                seconds in the current configuration)
        ###
        MAX_SUCCESS_RENDER_ROUNDS: 20
        LOADING_FINISHED_CHECK_INTERVAL: 25 #ms
        # List widget is allowed here as the ones with empty data will not be rendered
        ALLOWED_TO_BE_NASTY: [
            'top_locations_filter', 'current_location', 'new_items',
            'item_count', 'stream_info', 'custom_sources_info',
            'custom_source_item', 'custom_sources_list', 'list',
            'signals_count', 'mentions', 'signals']
        INTERVAL_FOR_99_PERCENT: 6 # seconds
        ACCELERATED_FINISH: 0.2 # seconds at most to finish after we had a lucky streak
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
            if Utils.inPrintMode()
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
            return if @shouldIgnoreWidget(message.widget)
            id = message.widget.params.widget_id
            @new_widgets.push(id)
            @id_to_name[id] = message.widget.params.name

        newWidgetRendered: (id) =>
            ###
                This callback is performed whenever a widget is rendered for
                the first time. Widgets publish this kind of event automatically
                when they do renderLayout() for the first time. The single
                exception to this are widgets without a template_name, who
                are considered "container" widgets whose sole role is to
                insert other widgets into the DOM.
            ###
            return if @shouldIgnoreWidget(loader.widgets[id])
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

            @finishLoadingAnimation() if @getProgress() >= 100

        finishLoadingAnimation: =>
            ###
                Hide the loading animation and stop polling for nasty widgets.
            ###
            # Fade out the loading animation with a nice transition, this way
            # the user gets a bit of extra closure and sees the last instant
            # step of the progress bar filling up, when widgets catch up with
            # the estimated progress
            $('#loading-animation').fadeOut()
            clearInterval(@intervalHandle)
            # Update the global "loading" flag from the application once the
            # loading is done
            App.isLoading = false
            @pipe.publish('/loading_animation_finished')
            # No need to listen to widget events once the loading animation
            # finishes
            @pipe.unsubscribe('/new_widget', @newWidgetAppeared)
            @pipe.unsubscribe('/new_widget_rendered', @newWidgetRendered)

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

            # If loading has finished already, we accelerate the progress to
            # still simulate a bit of a transition at the end
            if @momentLoadingFinished
                accelerated_progress = Math.min(
                    (current_time - @momentLoadingFinished) /
                    (@ACCELERATED_FINISH * 1000) * 100
                , 100)
                return Math.max(accelerated_progress, linear_progress)

            return linear_progress

        updateProgressBar: =>
            ###
                Update the progress bar animation.
            ###
            progress = @getProgress()
            $('#loading-animation .progress .bar').css("width", "#{progress}%")

        shouldIgnoreWidget: (widget) ->
            ###
                Check if a widget should be ignored by the loading animation
                completely. This happens when its element or a parent one has
                the .skip-loading-animation CSS class
            ###
            # Clearly we shouldn't wait for widgets if they don't have a
            # template to begin with
            return true unless widget.template_name?
            # Don't skip any widget in print mode, we need to make sure things
            # are rendered completely when we make the capture
            return false if Utils.inPrintMode()
            return widget.view.$el.hasClass('skip-loading-animation') or
                   widget.view.$el.closest('.skip-loading-animation').length
