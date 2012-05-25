define ['cs!widget'], (Widget) ->
    class TodoListWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo_list_widget.hjs'

        initialize: =>
            @renderLayout()

        get_todos: (params) =>
            if params.type != 'reset'
                return

            for todo in params.collection.models
                params_new =
                    'id': todo.id
                    'channels':
                        '/todos': @channel_mapping['/todos']

                container = @view.$el.find("#todo-list-container")
                Utils.injectWidget(container, 'todo_widget', params_new)

    return TodoListWidget