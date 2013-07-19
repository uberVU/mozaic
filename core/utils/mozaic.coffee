define [], () ->
    
    wrap: (fn, contextAttributes = {}) ->
        ###
            Wrap a function inside an exception-safe escapsulated scope, in
            order to catch any exception thrown from inside that function and
            obtain a relevant stack trace that can be logged and analyzed.

            contextAttributes is an extra set of attributes that can be logged
            if exceptions occur. Useful for debugging a corner-case exception
        ###
        # Don't wrap method if current environment is configured to let
        # exceptions pass through uncaught
        return fn if App.general.PASS_THROUGH_EXCEPTIONS
        return ->
            try
                return fn(arguments...)
            catch err
                # Throw back authentication exceptions, they are part of the
                # login system
                throw err if err.message is Constants.UNAUTHORIZED_EXCEPTION
                # Log exception along with any context attributes that were
                # specified for this method
                logger.handleException(err, contextAttributes)

    execute: (fn, contextAttributes = {}) ->
        ###
            Execute code inside an exception-safe scope
            @see Mozaic.wrap

            Example:
                Mozaic.execute(-> MyClass.doSomething())
        ###
        return @wrap(arguments...)()
