define ['cs!widget'], (Widget) ->

    class TodoListWidget extends Widget
        ###
            Wrapper for todo list to include aditional controls, like clearing
            all checked items
        ###
        subscribed_channels: ['/todos']
        template_name: 'templates/todo/list.hjs'

        events:
            'click .clear-items': 'clear_items'

        # The IDs of all checked TODOs. We need our reference for removing them
        # all at once
        checked_ids: []

        initialize: ->
            @renderLayout
                list_params:
                    channels:
                        '/items': @channel_mapping['/todos']
                    item: 'todo'
                    item_channels:
                        '/todos': @channel_mapping['/todos']
                    item_element: 'tr'

        get_todos: (params) =>
            return unless params.collection?

            @checked_ids = []
            for model in params.collection.models
                @checked_ids.push(model.id) if model.get('checked')

        clear_items: (e) =>
            e.preventDefault()
            for id in @checked_ids
                @deleteChannel("/todos/#{id}", {sync: false})
