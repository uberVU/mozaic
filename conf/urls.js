var App = App || {};

// Modules that should be loaded for any controller
App.default_loading_modules = ['cs!pubsub', 'cs!datasource', 'cs!widget_starter'];

// URLs that are available in our app
App.urls = {
	// The TODO list page is mapped to the empty (missing) hashbang
	'': {
		'controller': 'TodoPage',
		'layout': 'templates/todo_page.hjs'
	},
};