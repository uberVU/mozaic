define ['cs!widget'], (Widget) ->
    class TodoListWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo_list_widget.hjs'

        append: (todo) ->
            params_for_todo_widget =
                'id': todo.id
                'channels':
                    '/todos': @channel_mapping['/todos']

            container = @view.$el.find("#todo-list-container")
            Utils.injectWidget(container, 'todo_widget', params_for_todo_widget)

        reset: (params) ->
            @renderLayout()
            @append(todo) for todo in params.collection.models

        add: (params) ->
            @append(params.model)

        get_todos: (params) =>
            console.log(params)
            switch params.type
                when 'reset' then @reset(params)
                when 'add' then @add(params)

    return TodoListWidget