require(["cs!core/constants", "cs!core/utils", "cs!logger"], function() {
    require(["cs!loader"], function() {
        logger.level(App.general.LOG_LEVEL);
        loader.load_module("cs!router",        // Class to load & instantiate
                            function(router) { // Run this when class was loaded and instantiated
                                Backbone.history.start();
                            },
                            true,              // Instantiate the router
                            App.urls);         // Pass these params to the constructor of Router
    });
});