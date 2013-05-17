var App = App || {};
// Need to initialize this for the extend method to work in the tests
App.main_modules = App.main_modules || {};

App.the_modules = {
    // Custom Application Controller
    'core_application_controller': 'core/application_controller',

    // Backbone Model + Collection
    'model/todo': 'modules/todo/model/todo',
    'collection/todos': 'modules/todo/model/todo_collection',

    // Widgets
    'widget/todo_list': 'modules/todo/widget/list',
    'widget/todo': 'modules/todo/widget/todo',
    'widget/todo_form': 'modules/todo/widget/form',

    // Controllers
    'widget/TodoController': 'modules/todo/controller'
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
