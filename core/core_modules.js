var App = App || {};

App.main_modules = {
	// Core modules
	'constants': 'modules/constants',
	'loader': 'core/loader',
	'logger': 'core/logger',
	'module': 'core/module',
	'base_model': 'core/base_model',
	'layout': 'core/layout',
	'scrollable_widget': 'core/scrollable_widget',
	'widget': 'core/widget',
	'modal_widget': 'core/modal_widget',
	'mediator_widget': 'core/mediator_widget',
	'sync_url': 'core/sync_url_widget',
	'widget_starter': 'core/widget_starter',
	'channels_utils': 'core/channels_utils',
	'datasource': 'core/datasource',
	'pubsub': 'core/pubsub',
	'router': 'core/router',
	'controller': 'core/controller',
	'utils': 'core/utils',
	'fixtures': 'core/fixtures-loader',
	'loading_animation': 'core/loading_animation',
	'modal_window': 'core/modal_window',
	
	// Core collections
	'collection/raw_data': 'core/raw_data',
	
	// Core libraries
	'bootstrap': 'core/libs/bootstrap.min',
	
	// Core widgets
	'widget/item_count': 'core/widgets/item_count',
	'widget/order_by': 'core/widgets/order_by',
	'widget/tag_modal': 'core/widgets/tag_modal',
	'widget/url': 'core/widgets/url',
	'widget/sync_url': 'core/widgets/sync_url_widget',
	'widget/mediator_widget': 'core/widgets/mediator_widget',
	'widget/translate_text': 'core/widgets/translate_text',
};

if (typeof module != 'undefined') {
	module.exports.main_modules = App.main_modules;
}
