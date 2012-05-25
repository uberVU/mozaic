define ['cs!widget'], (Widget) ->

    class TodoWidget extends Widget
        subscribed_channels: ['/todos/{{id}}']
        template_name: 'templates/todo_widget.hjs'

        get_todos: (params) =>
            @renderLayout({"task" : params.model.get('task')})

    return TodoWidget