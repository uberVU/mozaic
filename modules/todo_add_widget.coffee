define ['cs!widget'], (Widget) ->
    class TodoAddWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo_add_widget.hjs'

        events:
            "keydown": "newTodo"

        initialize: =>
            @renderLayout()

        newTodo: (event) =>
            if event.keyCode == 13 # enter code
                window.ceva = $('#new-task input') 
                k = $('#new-task input').val()
                event.preventDefault()
                # TODO: trimite acum acel k care e textul introdus
                # la enter
                # @addChannel('/todos', {'id': '3', 'task' : k})

            console.log(event.keyCode)

    return TodoAddWidget