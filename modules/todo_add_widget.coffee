define ['cs!widget'], (Widget) ->
    class TodoAddWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo_add_widget.hjs'

        events:
            'click input[type="submit"]': 'newTodo'

        initialize: =>
            @renderLayout()

        newTodo: (event) =>
            input = @view.$el.find('input[name="task"]')
            task_name = input.attr('value')
            @addChannel('/todos', {task: task_name})
            input.attr('value', '')
            return false

    return TodoAddWidget