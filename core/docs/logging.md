# Logging in Mozaic

## StandardLogger
Base Logger class, uses browser console for log output. It knows three types of logs: `error`, `warn` and `info`, in descending order of seriousness. The accepted level of displaying logs is set as the only constructor parameter, and configured in the app through the `App.general.LOG_LEVEL` variable. A less _serious_ log level will include the ones above it as well.

```coffee
# The logger has a shorthand method for each of the log levels,
logger.info('You might be interested in this')
logger.warn('You should be interested in this')
logger.error('Dude... you gotta see this!')

# but also a method for handling exceptions. In this standard logger it just
# prints them to console, as well, but it's meant to be extended in logger
# subclasses, where they might be stored externally through various services
try
  ThisIsNeverGonnaWork;
catch err
  logger.handleException(err)
```

## SentryLogger
Logs exceptions to Sentry, using the Raven.js library

 - http://raven-js.readthedocs.org/en/latest/

You need to include the static Raven.js and TraceKit dependency in order for this logger to work

- https://github.com/getsentry/raven-js
- https://github.com/getsentry/TraceKit

```coffee
# The Sentry logger has a method for tracking authenticated users
logger.setUser
  id: 346
  email: 'andrei.ismail@ubervu.com'
```

## Installation
Set the `App.general.LOGGER_MODULE` config variable to the name of the logger module you want. E.g. `App.general.LOGGER_MODULE = 'standard_logger'`, this will bind the `cs!standard_logger` module to the global `window.logger` namespace
