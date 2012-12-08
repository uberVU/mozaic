var App = App || {};
// Need to initialize this for the extend method to work in the tests
App.main_modules = App.main_modules || {};

App.the_modules = {
		// Custom Application Controller
		'core_application_controller': 'core/application_controller',

		// Backbone Model + Collection
		'model/todo': 'modules/todo_model',
		'model/news': 'modules/news_model',
		'collection/todos': 'modules/todo_collection',
		'collection/news': 'modules/news_collection',

		// Widgets
		'widget/todo_list_widget': 'modules/todo_list_widget',
		'widget/todo_widget': 'modules/todo_widget',
		'widget/todo_add_widget': 'modules/todo_add_widget',
		'widget/news_list_widget': 'modules/news_list_widget',

		// Controllers
		'widget/TodoPage': 'modules/todo_page_controller',
		'widget/NewsPage': 'modules/news_page_controller'
};

// This is actually how we check if this is being ran
// in node.js enviromnent, _module_ being an omnipresent
// entity there
if (typeof module != 'undefined') {
    module.exports.main_modules = App.the_modules;
} else {
    for (var k in App.the_modules) {
        App.main_modules[k] = App.the_modules[k];
    }
}
