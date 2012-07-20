define ['cs!widget'], (Widget) ->
    class TodoAddWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo_add_widget.hjs'

        events:
            'click input[type="submit"]': 'newTodo'

        initialize: =>
            ###
                Whenever the widget is initialized, render the form.
            ###
            @renderLayout()

        newTodo: (event) =>
            ###
                Whenever user clicks on submit to add a new TODO,
                take the value from the DOM and publish a message
                to the datasource requesting that a new TODO item
                be created. This way, the datasource will be able
                to notify all interested widgets of the change
                and sync the data to the server (in our case, this
                is not necessary).
            ###

            # Get the value from the HTML form
            input = @view.$el.find('input[name="task"]')
            task_name = input.attr('value')

            # Publish the message to the datasource
            # (this method is in widget.coffee, the base class)
            @addChannel('/todos', {task: task_name})

            # Reset the HTML form
            input.attr('value', '')
            return false

    return TodoAddWidget
