require([
    'cs!utils/mozaic',
    'cs!core/constants',
    'cs!core/utils',
    'cs!' + App.general.LOGGER_MODULE
], function(MozaicLib, Constants, Utils, Logger) {
    require(['cs!loader'], function() {
        // Start Mozaic namespaces with core lib
        window.Mozaic = _.extend({}, MozaicLib);
        window.logger = new Logger(App.general.LOG_LEVEL);
        loader.load_module("cs!router",        // Class to load & instantiate
                            function(router) { // Run this when class was loaded and instantiated
                                Backbone.history.start();
                            },
                            true,              // Instantiate the router
                            App.urls);         // Pass these params to the constructor of Router
    });
});