define ['cs!widget'], (Widget) ->

    class TodoWidget extends Widget
        subscribed_channels: ['/todos/{{id}}']
        template_name: 'templates/todo_widget.hjs'

        get_todos: (params) =>
            ###
                Whenever any field of a TODO item changes, re-render it completely.
            ###
            @renderLayout({"task" : params.model.get('task')})

    return TodoWidget
