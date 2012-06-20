require.config({
	paths: _.extend(App.main_modules, {
		"chai": 		"tests/libs/chai",
		"expect": 		"tests/libs/expect", 
		"mocha": 		"tests/libs/mocha",
		"pubsub_tests": "tests/pubsub_tests"
	}),
	nodeRequire: require
});
