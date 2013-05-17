var App = App || {};

App.DataSourceConfig = {
    channel_types: {
        '/todos': {
            type: 'relational',
            collection: 'todos',
            populate_on_init: true
        }
    }
};
