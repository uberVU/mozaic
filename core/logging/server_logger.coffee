define ['cs!interceptor', 'cs!logger_store'], (Interceptor, LoggerStore) ->

    # Supported log types.
    NONE  = 0
    ERROR = 1
    WARN  = 2
    INFO  = 3

    # Need to initialize the logger store BEFORE this logger is actually
    # initialized.
    window.logger_store = new LoggerStore()

    logger =
        # Log level. Everything below this value will be logged.
        # This default value is overridden by App.general.LOG_LEVEL from general.js.
        log_level: INFO

        # Making bogus AJAX requests to this endpoint in order to force
        # flushing of client-side logs on periods of low activity.
        FLUSH_ENDPOINT : App.general.FRONTAPI_URL + '/api/dump_logs'

        # If your application doesn't perform any HTTP requests in this interval,
        # a manual log flushing routine will be triggered.
        FLUSH_INTERVAL: 70000 # ms

        # Periodic interval for checking. This needs to be much less than
        # FLUSH_INTERVAL because otherwise you can end up waiting up to at most
        # 2 * FLUSH_INTERVAL to perform a real flush (and that is deceiving!).
        FLUSH_CHECK_INTERVAL: 5000 # ms

        initialize: =>
            # Using this instead of Utils.now() to avoid dependency
            logger.last_flush = (new Date).getTime()
            setInterval(logger.try_flush_logs, logger.FLUSH_CHECK_INTERVAL)

        level: (level) ->
            # Set the current log level.
            logger.log_level = level

        _cleaned_stack_trace: (error) ->
            ###
                Get current stack trace, and clean-up the stacktrace.js related stack frames.
                @params {Error} error - Optional instance of error from which to extract the initial stack trace.
                                        If no error passed stacktrace.js will do it's best to produce one.
            ###
            stack_frames = printStackTrace e: error
            remaining_frames = []
            for stack_frame in stack_frames
                if stack_frame.match(/stacktrace.*js/)
                    continue
                if stack_frame.match(/_cleaned_stack_trace/)
                    continue
                if stack_frame.match(/server_logger/)
                    continue
                remaining_frames.push(stack_frame)
            return JSON.stringify(remaining_frames)

        _log: (type, level=INFO, args = {}) ->
            ###
                Generic message logger.
                @private
                @params {String} type - 'log', 'warn', 'error'
                @params {String} level - Optional, can be NONE, INFO, WARN, ERROR
                @args {Object} - Optional, arguments object passed to info(), warn(), error()
            ###

            # Check if the error received should be sent to the server.
            sendToServer = level <= logger.log_level

            if sendToServer
                # Print to console.
                console[type]?.apply?(console, args)

                # Send logs to the server.
                logger_store.store level, args[0], args[1]

        info: () ->
            # Log a message with info level
            logger._log "log", INFO, arguments

        warn: () ->
            # Log a message with warn level
            logger._log "warn", WARN, arguments

        error: (error) ->
            ###
                Log a message with error level.
                @param {String|Error} message - Optional error or message string
            ###
            # Disambiguate arguments.
            # If first argument is string, wrap it inside an error.
            # However using a string is not encouraged.
            # Always use Errors because they capture stacktraces which are extremely usefull when debugging.
            if _.isString error then error = new Error error
            if error instanceof Error
                args = [
                    # We can extract an error message and a stack trace from an Error.
                    error.message
                    logger._cleaned_stack_trace error
                ]

            logger._log "error", ERROR, args

        try_flush_logs: () ->
            ###
                Try to send available logs to server via a bogus XHR request.
                (this will actually send them if and only if there has been
                no other API activity lately, thus no way to piggy-back the logs).

                WARNING: this request doesn't need to actually contain
                anything, because the logs will be automatically piggy-backed
                via custom HTTP headers.

                NOTE: in general, this should happen very rarely, and we
                recommend that you set your FLUSH_INTERVAL to something
                less often than your current user calls.
            ###
            now = new Date().getTime()
            if now - logger.last_flush >= logger.FLUSH_INTERVAL
                if logger_store.items_left() > 0
                    $.ajax({type: 'GET', url: logger.FLUSH_ENDPOINT})
                logger.last_flush = now


    _getAllowedSizeOfMozaicLogsHeader = (xhr, settings) ->
        ###
            Calculate the space available for logs, by taking into account that a character is sent in a byte.
              * starts with MAX_ALLOWED_REQUEST_SIZE, this is set in general.js
              * substracts the size of the payload (if it's a POST/PUT request)
              * substracts the size of the url
              * substracts 0.5 kB average request size sans url and payload
            @param {Object} xhr - jqXHR object
            @param {Object} settings - $.ajax settings object
        ###
        maxAllowedRequestSize = 8 # kB
        sizeOfPayload = if settings.type in ['PUT', 'POST'] and settings.data? then JSON.stringify(settings.data).length / 1000 else 0 # kB
        sizeOfUrl = settings.url.length / 1000 # kB
        averageRequestSize = 0.8 # kB
        maxAllowedRequestSize - sizeOfPayload - sizeOfUrl - averageRequestSize


    Interceptor.addAjaxSendRequestCallback (e, xhr, settings) ->
        ###
            Intercepts all outgoint ajax requests and attaches mozaic logs through headers.
            @param {Object} e = jQuery.Event
            @param {Object} xhr - jqXHR object
            @param {Object} settings - $.ajax settings object
        ###

        available_space = _getAllowedSizeOfMozaicLogsHeader xhr, settings
        available_logs = logger_store.retrieve_available_logs available_space

        if available_logs? and available_logs.length > 0
            xhr.setRequestHeader('Mozaic-logs', available_logs)
        logger.last_flush = new Date().getTime()


    window.logger = logger
    logger.initialize()
    return logger
