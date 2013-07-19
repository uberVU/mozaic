var App = App || {};

App.conf_files = ['conf/datasource.js',
                  'conf/urls.js',
                  'conf/forms.js',
                  'core/core_modules.js',
                  'conf/modules.js'];
App.conf_files_bundle_name = 'conf_bundle.js';

// Static libs included on every HTTP request
// If environment is production, these will be served as a single bundle.
App.static_libs = ['core/libs/json2.js',
                   'core/libs/jquery/jquery-1.8.3.js',
                   'core/libs/jquery/jquery.event.fix.js',
                   'core/libs/jquery/jquery-ui-1.9.2.custom.js',
                   'core/libs/jquery/jquery.timeago.js',
                   'core/libs/jquery/jquery.idletimer.js',
                   'core/libs/jquery/jquery.colorpicker.js',
                   'core/libs/bootstrap.js',
                   'core/libs/underscore.js',
                   'core/libs/backbone/backbone-0.9.1.js',
                   'core/libs/backbone/backbone.queryparams.js',
                   'core/libs/backbone/backbone-forms.js',
                   'core/libs/handlebars-1.0.beta.6.js',
                   'core/libs/underscore.string.js',
                   'core/libs/moment-1.6.2.js',
                   'core/libs/jsuri-1.1.1.js'];
App.static_libs_bundle_name = 'static_bundle.js';

// IE7 JS bundle

App.static_ie7_libs = ['core/libs/ie7.js'];
App.static_ie7_libs_bundle_name = 'static_ie7_bundle.js';

// CSS bundles
App.static_css = ['skin/bootstrap/css/bootstrap-responsive.css',
                  'skin/bootstrap/css/bootstrap.css',
                  'skin/main.css']
App.static_css_bundle_name = 'css/static_css.css';

if (typeof module != 'undefined') {
    // Configs
    module.exports.conf_files = App.conf_files;
    module.exports.conf_files_bundle_name = App.conf_files_bundle_name;
    // JS
    module.exports.static_libs = App.static_libs;
    module.exports.static_libs_bundle_name = App.static_libs_bundle_name;
    module.exports.static_ie7_libs = App.static_ie7_libs;
    module.exports.static_ie7_libs_bundle_name = App.static_ie7_libs_bundle_name;
    // CSS
    module.exports.static_css = App.static_css;
    module.exports.static_css_bundle_name = App.static_css_bundle_name;
}
