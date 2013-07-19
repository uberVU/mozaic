// This config file is only for extending the existing variables from general.js
// and cannot set a new one. To introduce a new config var one must add it to
// general.js file first, and only then personalize it for local scenarios here,
// if needed
var App = App || {};

var LOG_LEVEL = {
    NONE: 0,
    ERROR: 1,
    WARN: 2,
    INFO: 3
};

App.user = {
    STATIC_URL: 'http://ubervu.localhost',
    LOG_LEVEL: LOG_LEVEL.WARN
};
