// This config file is only for extending the existing variables from general.js
// and cannot set a new one. To introduce a new config var one must add it to
// general.js file first, and only then personalize it for local scenarios here,
// if needed
var App = App || {};

// Paths for working with an external frontend (useful especially when not
// having the frontend installed locally)
var FRONTAPI = {
    LOCAL: 'http://127.0.0.1:8000',
    APP: 'http://app.ubervu.com',
    TEST: 'http://test-app.ubervu.local',
    WL: 'http://wldemo.ubervu.com',
    BOGDAN: 'http://192.168.1.29:8000'
};

var LOG_LEVEL = {
    NONE: 0,
    ERROR: 1,
    WARN: 2,
    INFO: 3
};

App.user = {
    FRONTAPI_URL: FRONTAPI.TEST,
    FRONTEND_URL: FRONTAPI.TEST,
    STATIC_URL: 'http://ubervu.github.io/mozaic/uberdo',
    LOG_LEVEL: LOG_LEVEL.ERROR
};