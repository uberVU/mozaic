# Logs handling #

## default_logger ##
Functions as a regular logger; it throws logs to the javascript console. This is controlled by App.general.LOG_LEVEL configuration flag.

## server_logger ##
On top of default console logging, the logs are also sent as HTTP request headers. This piggybacking enables server-side logging.

## installation ##
Just add the logger module to your modules conf file, overriding the core `logger` module.

## features ##
The logging module exposes 3 methods: `error`, `warn`, `info`. All these methods support both an Error instance or simply a String for convenience
Every time any of these methods are called an entry is stashed in the logger store containing stack traces, user event leading up to that message and all optional context variables the user chooses to pass to the logger methods.
In case of a `logger.error` that error is also thrown to stop execution of the current method.
