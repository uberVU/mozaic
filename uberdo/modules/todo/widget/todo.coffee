define ['cs!widget'], (Widget) ->

    class TodoWidget extends Widget
        subscribed_channels: ['/todos/{{id}}']
        template_name: 'templates/todo/todo.hjs'

        events:
            'click input[type=checkbox]': 'toggle'
            'click a.star': 'star'
            'click a.unstar': 'unstar'
            'click a.delete': 'remove'

        params_defaults:
            id: 'data-params'

        get_todos: (params) =>
            ###
                Whenever any field of a TODO item changes, re-render it completely.
            ###
            # TODO, remove itself when undefined
            if not params or not params.type == 'change'
                return

            # Fetch model
            model = params.model

            # Render layout
            @renderLayout
                id: model.get('id') or model.id
                name: model.get('name')
                checked: model.get('checked')
                starred: model.get('starred')

        toggle: (e) =>
            checked = $(e.currentTarget).is(':checked')
            @modifyChannel('/todos/{{id}}', {checked: checked, timestamp: @now()}, {sync: false})

        star: (e) =>
            e.preventDefault()
            @modifyChannel('/todos/{{id}}', {starred: true, timestamp: @now()}, {sync: false})
            false

        unstar: (e) =>
            e.preventDefault()
            @modifyChannel('/todos/{{id}}', {starred: false, timestamp: @now()}, {sync: false})

        now: () ->
            return new Date().getTime()

        remove: (e) =>
            e.preventDefault()
            @deleteChannel("/todos/#{@id}", {sync: false})
