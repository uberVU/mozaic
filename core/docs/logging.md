# Logs handling #

## default_logger ##
Functions as a regular logger; it throws logs to the javascript console.

## server_logger ##
On top of default console logging, the logs are also sent as HTTP request headers. This piggybacking enables server-side logging.

## installation ##
Just add the logger module to your modules conf file, overriding the core `logger` module.