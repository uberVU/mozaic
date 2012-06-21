# Commonly used libraries.
global._ = require('../core/libs/underscore-1.3.3.js')
global.Backbone = require('../core/libs/backbone/backbone-0.9.1.js')
_.extend(_, require('../core/libs/underscore.string.js'))

# Config files, the App object is not defined in this context, se we need to define it.
App = {}

_.extend(App, require('../conf/general.js'))
# Nee to do this because datasource.js uses App.general
global.App = App
_.extend(App, require('../conf/datasource.js'))
_.extend(App, require('../conf/modules.js'))
_.extend(App, require('../conf/urls.js'))

# Setup require to work in node. Notice the define function assignment
# TODO - find a smarter solution for config, as almost the same in done in rconf_test.
define = require('requirejs')
define.config({
	baseUrl: '../',
	paths: _.extend(App.main_modules, {
		"chai": 			"tests/libs/chai",
		"expect": 			"tests/libs/expect",
		"mocha": 			"tests/libs/mocha",
		"pubsub_tests": 	"tests/pubsub_tests",
		"rawdata_tests": 	"tests/rawdata_tests"
	}),
	nodeRequire: require
})


# Call any tests that need to be run.
define (['cs!pubsub_tests'])
define (['cs!rawdata_tests'])
