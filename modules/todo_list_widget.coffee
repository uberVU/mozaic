define ['cs!widget'], (Widget) ->
    class TodoListWidget extends Widget
        subscribed_channels: ['/todos']
        template_name: 'templates/todo_list_widget.hjs'

        events:
            'click a.clear-items': 'clear_items'

        append: (todo) ->
            ###
                This method injects a TODO widget into the DOM.
                The widget needs to know the /todos channel in order
                to listen to changes for an individual TODO item.
            ###
            params_for_todo_widget =
                'id': todo.id
                'channels':
                    '/todos': @channel_mapping['/todos']

            container = @view.$el.find("#todo-list-container")
            Utils.injectWidget(container, 'todo_widget', params_for_todo_widget)

        reset: (params) ->
            ###
                This method is called to reset the graphical representation of
                the todos from scratch (because the collection itself has
                been reset from scratch).
            ###
            # Fetch models
            models = params.collection.models
            # Store ids
            @ids = (model.get 'id' for model in models when model.get 'checked')
            # Re-render the clean HTML
            @renderLayout()
            # Inject the TODO widgets
            @append(todo) for todo in models

        add: (params) ->
            ###
                This method is called to add a new model to the graphical
                representation of the todos, whenever the collection
                notifies the widget that a new element has been added.
            ###
            @append(params.model)

        change: (params) ->
            # Sort collection before resetting layout
            params.model.collection.sort()

        get_todos: (params) =>
            ###
                This method will be called whenever there are changes
                to the /todos channel. Changes can be of multiple types,
                as this data channel is actually a Backbone Collection.
                (There is another type of channel as well, which can store raw
                JSON data).
            ###
            switch params.type
                when 'reset' then @reset(params)
                when 'add' then @add(params)
                when 'change' then @change(params)
                when 'remove' then @reset(params)

        clear_items: (e) =>
            for id in @ids
                @removeChannel '/todos', { id: id }
            false

    return TodoListWidget