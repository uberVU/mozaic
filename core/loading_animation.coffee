define ['cs!module'], (Module) ->
    class LoadingAnimation extends Module
        ###
            How many consecutive times #of announced widgets should equal
            #of rendered widgets before declaring that all was loaded.

            (note: equality isn't tested strictly).
        ###
        MAX_CONSECUTIVE_ZEROS: 5

        ###
            How often to check for new widgets vs. rendered ones.
        ###
        COUNTER_CHECK_INTERVAL: 100 #ms

        ###
            Hard-coded list of widgets which don't do @renderLayout()
            and it's ok for them not to.
        ###
        ALLOWED_IN_DIFFERENCE: ['top_locations', 'current_location', 'new_mentions']

        ###
            Grow the progress bar linearly until 99%.
        ###
        INTERVAL_FOR_99_PERCENT: 5000 #ms

        ###
            The interval before we start reporting uninitialized widgets.
        ###
        REPORT_NASTY_WIDGETS_INTERVAL: 15 # seconds

        checking_counters: false
        new_widgets: 0
        new_widgets_list: []
        rendered_widgets: 0
        rendered_widgets_list: []
        consecutive_zeros: 0
        intervalID: null
        id_to_name: {}
        start_time: 0
        iterations: 0

        constructor :->

        initialize: =>
            @pipe = loader.get_module('pubsub')
            @pipe.subscribe('/new_widget', @new_widget_appeared)
            @pipe.subscribe('/new_widget_rendered', @new_widget_rendered)

        new_widget_appeared: (message) =>
            @new_widgets = @new_widgets + 1
            widget_id = message.widget.params['widget_id']
            @new_widgets_list.push(widget_id)
            @id_to_name[widget_id] = message.widget.params['name']
            if not @checking_counters
                @startCheckingCounters()

        new_widget_rendered: (id) =>
            @rendered_widgets = @rendered_widgets + 1
            @rendered_widgets_list.push(id)

        startCheckingCounters: =>
            @start_time = new Date().getTime()
            @intervalID = setInterval(@checkCounters, @COUNTER_CHECK_INTERVAL)
            @checking_counters = true

        nonRenderedWidgetsAreOK: =>
            nasty_widgets = _.difference(@new_widgets_list, @rendered_widgets_list)
            current_time = new Date().getTime()
            if current_time - @start_time > 1000 * @REPORT_NASTY_WIDGETS_INTERVAL
                @iterations = @iterations + 1
                if @iterations % 20 == 0
                    console.log('Nasty widgets: ' + nasty_widgets)
            for id in nasty_widgets
                if not _.contains(@ALLOWED_IN_DIFFERENCE, @id_to_name[id])
                    return false
            return true

        getProgress: =>
            current_time = new Date().getTime()
            difference = Math.min(current_time - @start_time, @INTERVAL_FOR_99_PERCENT)
            difference / @INTERVAL_FOR_99_PERCENT * 99

        checkCounters: =>
            # Update the progress bar
            progress = @getProgress()
            $('#loading-animation .progress .bar').css("width", "#{progress}%")

            if not @nonRenderedWidgetsAreOK()
                @consecutive_zeros = 0
                return

            @consecutive_zeros = @consecutive_zeros + 1

            if @consecutive_zeros >= @MAX_CONSECUTIVE_ZEROS
                $('#loading-animation').hide()
                clearInterval(@intervalID)