define ['cs!widget'], (Widget) ->

    class TodoFormWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo/form.hjs'

        elements:
            input: 'input[name="task"]'
            button: 'input[type="submit"]'

        events:
            'keyup @input': 'onKeyUp'
            'click @button': 'newTodo'

        initialize: =>
            ###
                Whenever the widget is initialized, render the form.
            ###
            @renderLayout()

        newTodo: (e) =>
            ###
                Whenever user clicks on submit to add a new TODO,
                take the value from the DOM and publish a message
                to the datasource requesting that a new TODO item
                be created. This way, the datasource will be able
                to notify all interested widgets of the change
                and sync the data to the server (in our case, this
                is not necessary).
            ###
            e.preventDefault()

            # Get the value from the HTML form
            task_name = @input.attr('value')

            # Publish the message to the datasource
            # (this method is in widget.coffee, the base class)
            todo =
                id: _.uniqueId() + 1
                name: task_name
            @addChannel('/todos', todo, false)

            # Reset the HTML form
            @input.attr('value', '')

        onKeyUp: (e) =>
            # Whenever ENTER is pressed
            if e.keyCode is 13
                @button.click()
                e.preventDefault()
            # Only make the submit button available when there's text entered
            # in the input
            @button.prop('disabled', not $(e.currentTarget).val())
