define ['cs!widget'], (Widget) ->

    class TodoFormWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo/form.hjs'

        events:
            'click input[type="submit"]': 'newTodo'

        initialize: =>
            ###
                Whenever the widget is initialized, render the form.
            ###
            @renderLayout()

            # Fetch input and add keyup events
            @input = @view.$el.find('input[name="task"]')
            @input.on('keyup', @onKeyUp)

            # Fetch button
            @button = @view.$el.find('input[type="submit"]')

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
            task_name = @input.attr('value')

            # Publish the message to the datasource
            # (this method is in widget.coffee, the base class)
            todo =
                id: _.uniqueId() + 1
                name: task_name
            @addChannel('/todos', todo, false)

            # Reset the HTML form
            @input.attr('value', '')
            return false

        onKeyUp: (e) =>


            if e.keyCode == 13
                @button.click()
                e.preventDefault()
            if $(e.currentTarget).val()
                @button.prop('disabled', false)
            else
                @button.prop('disabled', true)
