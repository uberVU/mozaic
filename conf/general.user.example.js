// This config file is only for extending the existing variables from general.js
// and cannot set a new one. To introduce a new config var one must add it to
// general.js file first, and only then personalize it for local scenarios here,
// if needed
var App = App || {};

// Paths for working with an external frontend (useful especially when not
// having the frontend installed locally)
var FRONTEND = {
    LOCAL: 'http://127.0.0.1:8000',
    APP: 'http://app.ubervu.com',
    TEST: 'http://test-app.ubervu.local',
    WL: 'http://wldemo.com'
};

var LOG_LEVEL = {
    NONE: 0,
    ERROR: 1,
    WARN: 2,
    INFO: 3
};

App.user = {
    FRONTEND_URL: FRONTEND.TEST,
    STATIC_URL: 'http://ubervu.localhost',
    LOG_LEVEL: LOG_LEVEL.INFO
};