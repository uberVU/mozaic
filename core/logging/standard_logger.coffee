define [], ->
    class StandardLogger
        ###
            Default Logger class, prints logs to browser console directly, if
            their level is the same or above the one it was configured to
        ###
        # Possible log levels for a logger, higher values include the ones
        # lower than themselves, as well
        @LOG_LEVEL:
            NONE: 0
            ERROR: 1
            WARN: 2
            INFO: 3
        
        constructor: (logLevel) ->
            # The log level of a logger instance can be set when creating it,
            # otherwise it defaults to only logging warn or error messages
            @logLevel = if logLevel? then logLevel \
                                     else @constructor.LOG_LEVEL.WARN

        error: ->
            ###
                Log a message at INFO level
            ###
            @_log(@constructor.LOG_LEVEL.ERROR, arguments...)

        warn: ->
            ###
                Log a message at INFO level
            ###
            @_log(@constructor.LOG_LEVEL.WARN, arguments...)

        info: ->
            ###
                Log a message at INFO level
            ###
            @_log(@constructor.LOG_LEVEL.INFO, arguments...)

        handleException: (e, params...) ->
            ###
                Handle caught Error instance.

                In this standard implementation the error message will simply
                be logged at ERROR level. Exceptions should be left uncaught in
                dev environment in order to intercept their stack trace 
            ###
            # Allow extra params to be passed along an exception
            @_log(@constructor.LOG_LEVEL.ERROR, e.toString(), params...)

        _log: (logLevel, params...) ->
            ###
                Log a message to browser console, if its level meets the
                current configuration
            ###
            return if logLevel > @logLevel
            # Get the most appropriate console method based on the log level of
            # this message
            method = switch logLevel
                when @constructor.LOG_LEVEL.ERROR then 'error'
                when @constructor.LOG_LEVEL.WARN then 'warn'
                else 'log'
            console[method](params...)
