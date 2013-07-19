var App = App || {};

App.general = {
    USE_MOCKS: false,
    FRONTEND_URL: 'http://127.0.0.1:8000',
    STATIC_URL: '/static/app',
    LOGGER_MODULE: 'standard_logger',
    LOG_LEVEL: 2, // ERROR & WARN
    LOGIN_PAGE: '{{FRONTEND_URL}}/front/login',
    LOGIN_URL: '{{FRONTEND_URL}}/front-api/v1/login/',
    LOGOUT_URL: '{{FRONTEND_URL}}/front-api/v1/logout/',
    CURRENT_USER_URL: '{{FRONTEND_URL}}/front-api/v1/current/',
    CURRENT_USER_TIMEOUT: 60 * 1000,
    DEFAULT_PAGE_AFTER_LOGIN: 'index.html',
    PAGE_LAYOUT: 'templates/layout.hjs',
    SVG_PATH: '/public/svg',
    ENVIRONMENT: 'testing',

    //CSS files used for branding purposes
    EXTRA_BRANDING: [],

    // Throw exceptions and don't catch them with our wrapper
    // so that we can debug them easier.
    THROW_UNCAUGHT_EXCEPTIONS: true,

    // Don't use precompiled templates
    USE_PRECOMPILED_TEMPLATES: false,

    IMAGE_UPLOAD_BUCKET_URL: 'https://s3.amazonaws.com/unleashed-static/',

    // Mixpanel code checks for ENVIRONMENT == 'production' before using
    // these guys.
    MIXPANEL_CONFIG: { test: false, debug: false },
    MIXPANEL_TOKEN: "9f8b3d1b3546a9679d0750b256ee824d",

    // User inactive interval
    CHECK_MAINTENANCE_MODE_INTERVAL: 3 * 60 * 1000,

    // Timespan after which the 'idle' event is triggered.
    CHECK_USER_INACTIVE_INTERVAL: 15*60*1000, // 15min

    // Static maintenance page
    MAINTENANCE_PAGE: '/maintenance',

    // Number of consecutive timeouted requests.
    OFFLINE_TIMEOUT_REQUESTS_LIMIT: 5,

    // JS file to be used as entry-point for the application
    ENTRY_POINT: 'main'
};
// Can't use precompiled templates if not in production
// because the bundle.sh is not run every time and prob
// tpl.js doesn't exist
if (App.general.ENVIRONMENT !== 'production')
    App.general.USE_PRECOMPILED_TEMPLATES = false;

if (typeof module != 'undefined') {
    module.exports.general = App.general;
}
