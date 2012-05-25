define [], ->
    NONE  = 0
    ERROR = 1
    WARN  =    2
    INFO  = 3

    logger =
        log_level: INFO

        # Set the current log level
        level: (level) -> logger.log_level = level

        # Log a message, optionally specifying the log level
        _log: (type, level=INFO, msg)-> console[type].apply(console, msg) if level <= logger.log_level

        # Log a message with info level
        info: () -> logger._log("log", INFO, arguments)

        # Log a message with warn level
        warn: () -> logger._log("warn", WARN, arguments)

        # Log a message with error level
        error: () -> logger._log("error", ERROR, arguments)

    window.logger = logger
    return logger