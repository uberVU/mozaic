define ['cs!interceptor', 'cs!logger_store'], (Interceptor, LoggerStore) ->

    NONE = 0
    CRITICAL = 1
    ERROR = 2
    WARN = 3
    INFO = 4
    DEBUG = 5

    window.logger_store = new LoggerStore()

    if !console
        console = {}

    logger =
        log_level: INFO
        # Set the current log level
        level: (level) -> logger.log_level = level

        # Log a message, optionally specifying the log level
        _log: (type, level=INFO, msg)->
            if level <= logger.log_level
                console[type]?.apply?(console, msg)
                # store message
                window.logger_store.store(level, msg)

        # Log a message with debug level
        debug: () -> logger._log("debug", DEBUG, arguments)

        # Log a message with info level
        info: () -> logger._log("log", INFO, arguments)

        # Log a message with warn level
        warn: () -> logger._log("warn", WARN, arguments)

        # Log a message with error level
        error: () -> logger._log("error", ERROR, arguments)

        # Log a message with critical level
        critical: () -> logger._log("critical", CRITICAL, arguments)

    Interceptor.addAjaxSendRequestCallback((e, xhr, settings) ->
        available_logs = window.logger_store.get_available_logs()
        if available_logs.length > 0
            xhr.setRequestHeader('Mozaic-logs', available_logs)
        window.logger_store.flushed = true
    )

    window.logger = logger
    return logger