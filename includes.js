/*
 * Include CSS and JS files utilities, with or without IE support.
 */
function includeJsFile(file) {
    document.write('<script type="text/javascript" src="' +
                   file + '"><\/sc' + 'ript/>');
}

function includeJsFileIE(file, ie_version) {
    document.write('<!--[if IE '+ ie_version +
                   ']><script type="text/javascript" src="' +
                   file + '"><\/sc' + 'ript/><![endif]-->');
}

function includeCssFile(file) {
    document.write('<link type="text/css" rel="stylesheet" href="' +
                   file + '"/>');
}

function includeCssFileIE(file, ie_version) {
    document.write('<!--[if IE ' + ie_version +
                   ']><link type="text/css" src="' +
                   file + '"/><![endif]-->');
}

/*
 * Retrieve static URL - versioned or not.
 */
function getStaticUrl() {
    var static_url = App.general.STATIC_URL + '/';
    if (App.version) {
        static_url = static_url + App.version + '/';
    }
    return static_url;
}


function includeCssAndJs() {
    includeStaticFilesInBundles();
    includeBranding();
    includeMainEntryPoint();
    includeTemplates();
}

/*
 * Include static CSS and JS bundles.
 *
 * Basically, we have the following bundles:
 * - 1 bundle for config files (3 of them are loaded separately beforehand)
 *   (these are loaded from the same host as index.html, while the rest
 *    are loaded via the CDN in production. One good reason for this is
 *    that we do not want config files cached by the CDN).
 *
 * - 1 bundle for 3rd party libraries (jQuery, Backbone, etc.)
 * - 1 bundle for Unleashed CoffeeScript code
 * - 1 bundle for IE CSS and 1 for IE JS
 *
 * These are either served split into each individual file (in development),
 * or bundled (in production).
 */
function includeStaticFilesInBundles() {
    if (App.general.ENVIRONMENT == 'production') {
        includeStaticFilesInBundles_Production();
    } else {
        includeStaticFilesInBundles_Development();
    }
}

function includeStaticFilesInBundles_Production() {
    includeJsFile(App.conf_files_bundle_name);
    // Include different CSS files for mobile devices
    // #4964 - Disable CSS bundling on production (temporarily)
    if (isMobileDevice()) {
        for (var i = 0; i < App.static_touch_css.length; i++) {
            includeCssFile(getStaticUrl() + App.static_touch_css[i]);
        }
        // includeCssFile(getStaticUrl() + App.static_touch_css_bundle_name);
    } else {
        for (var i = 0; i < App.static_css.length; i++) {
            includeCssFile(getStaticUrl() + App.static_css[i]);
        }
        // includeCssFile(getStaticUrl() + App.static_css_bundle_name);
    }
    includeJsFile(getStaticUrl() + App.static_libs_bundle_name);
    includeJsFileIE(getStaticUrl() + App.static_ie7_libs_bundle_name, 7);
}

function includeStaticFilesInBundles_Development() {
    for (var i = 0; i < App.conf_files.length; i++) {
        includeJsFile(App.conf_files[i]);
    }
    // Include different CSS files for mobile devices
    if (isMobileDevice()) {
        for (var i = 0; i < App.static_touch_css.length; i++) {
            includeCssFile(getStaticUrl() + App.static_touch_css[i]);
        }
    } else {
        for (var i = 0; i < App.static_css.length; i++) {
            includeCssFile(getStaticUrl() + App.static_css[i]);
        }
    }
    for (var i = 0; i < App.static_libs.length; i++) {
        includeJsFile(getStaticUrl() + App.static_libs[i]);
    }
    for (var i = 0; i < App.static_ie7_libs.length; i++) {
        includeJsFileIE(getStaticUrl() + App.static_ie7_libs[i], 7);
    }
    if (App.general.USE_MOCKS) {
        includeJsFile(getStaticUrl() + 'tests/libs/jquery.mockjax.js');
    }
}

/*
 * Branding CSS allows us to do custom branding per each domain.
 *
 * We call a fixed URL relative to the current host, which renders a CSS
 * using a templating engine, customizing that CSS so that it gets the color
 * scheme of the current domain.
 *
 * NOTE: this cannot be served from the CDN because it's dynamically generated.
 *       Also, we cannot use includeCss because we need it to have an ID
 *       (#custom-css).
 */
function includeBranding() {

    if (App.EXTRA_BRANDING) {
        var id = "'custom-css' ";
        for(var i = 0; i < App.EXTRA_BRANDING.length;i++) {
            if (i > 0) {
                id = "'custom-css-" + i + "' ";
            }
            document.write("<link rel='stylesheet' id=" + id +
                        "href= '" + App.EXTRA_BRANDING[i] + "'/>");
        }
    }
}

/*
 * Include templates bundle, if needed.
 *
 * In development, templates are fetched on-the-fly using require.JS,
 * while in production, they are in a single bundled, pre-compiled.
 *
 * NOTE: it is important to pre-compile them for 2 reasons:
 *    1) It's a lot faster to compile them server-side rather than
 *       have the client browser compile it
 *    2) Handlebars .hjs to anonymous function compiler is full of
 *       memory leaks. This makes it hard to use client-side, where
 *       we want to avoid memleaks at all costs.
 */
function includeTemplates() {
    // Include files and bundles which depend on require
    if (App.general.ENVIRONMENT === 'production') {
        includeJsFile(getStaticUrl() + 'tpl.js');
    }
}

/*
 * Include the main application entry-point. This is powered by require.JS
 */
function includeMainEntryPoint() {
    document.write('<script type="text/javascript" data-main="rconf_main" ' +
                   'src="require.js"></script>');
}

/*
 * Overrides general config with user config from general.user.js.
 *
 * Kudos to @skidding for coming up with the idea that general.user.js
 * cannot override a variable unless it's already defined in general.js.
 */
function overrideGeneralConfigWithUserConfig() {
    // Pour user configuration over general one
    if (App.user) {
        for (var prop in App.user) {
            // Only existing variables can be extended, new ones are ignore in order
            // to prevent users from adding new config variables in their user file
            if (typeof(App.general[prop]) != 'undefined') {
                App.general[prop] = App.user[prop];
            }
        }
    }
}

/*
 * Replace nested config variables. Example:
 *
 *     App.general = {
 *         FRONTAPI_URL: 'http://127.0.0.1:8000',
 *         LOGIN_PAGE: '{{FRONTAPI_URL}}/front/login',
 *         ...
 */
function replaceReferencesFromConfigVariables() {
    for (var prop in App.general) {
        // Only string properties can contain references to other ones
        if (typeof(App.general[prop]) != 'string') {
            continue;
        }
        App.general[prop] = App.general[prop].replace(/{{(.+?)}}/g, function(match, name) {
            if (typeof(App.general[name]) != 'undefined') {
                return App.general[name];
            } else {
                return match;
            }
        });
    }
};

/**
 * Check if current user is browsing from a mobile devices (normally with touch
 * capabilities)
 * XXX user agent sniffing is not an ideal technique since it can change at any
 * time and also new devices can appear, but does the job for an MVP situation
 */
function isMobileDevice() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|Windows Phone/i.test(navigator.userAgent)
}

overrideGeneralConfigWithUserConfig();
replaceReferencesFromConfigVariables();
includeCssAndJs();
