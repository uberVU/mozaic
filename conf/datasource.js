var App = App || {};

App.DataSourceConfig = {
    channel_types: {
        '/todos': {
            type: 'relational',
            collection: 'todos'
        },
        '/news': {
            type: 'relational',
            collection: 'news'
        }
    }
};
