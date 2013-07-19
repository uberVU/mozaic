define ['cs!standard_logger'], (StandardLogger) ->
    
    class SentryLogger extends StandardLogger
        ###
            Logs exceptions to Sentry, using the Raven.js library
            - http://raven-js.readthedocs.org/en/latest/

            You need to include the static Raven.js and TraceKit dependency in
            order for this module to work
            - https://github.com/getsentry/raven-js
            - https://github.com/getsentry/TraceKit
        ###
        constructor: ->
            super(arguments...)
            # Configure the Sentry client with our DSN
            Raven.config(App.general.SENTRY_PUBLIC_DSN).install()

        setUser: (attributes) ->
            ###
                Register a set of user attributes to the Raven library, in
                order to have exceptions tracked by user in the Sentry console
            ###
            Raven.setUser(attributes)

        handleException: (err, contextAttributes = {}) ->
            ###
                Handle all exception through the Sentry service. The second
                parameter is used for attaching extra tags to the Raven call
            ###
            Raven.captureException(err, tags: contextAttributes)
