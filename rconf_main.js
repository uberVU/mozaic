require.config({
	paths: App.main_modules // concatenates from core/core_modules.coffee and conf/modules.js
});

require([
    "cs!datasource",
    "cs!constants", 
    "cs!utils", 
    "cs!logger",
    "cs!loader" 
], function (
    datasource,
    Constants, 
    Utils, 
    logger,
    loader 
) {
    logger.level(App.general.LOG_LEVEL);
    loader.load_module(
        "cs!router", // Class to load & instantiate
        function(router) { // Run this when class was loaded and instantiated
            Backbone.sync = function (method, model, options) {
                if (options.success) return options.success(model);
            };
            Backbone.history.start ();
        },
        true, // Instantiate the router
        App.urls
    ); // Pass these params to the constructor of Router
});
