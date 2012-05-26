define ['cs!widget'], (Widget) ->

    class TodoWidget extends Widget
        subscribed_channels: ['/todos/{{id}}']
        template_name: 'templates/todo_widget.hjs'

        events:
            'click input[type=checkbox]': 'toggle'
            'click a.star': 'star'
            'click a.unstar': 'unstar'
            'click a.delete': 'remove'

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
                id: model.get('id')
                name: model.get('name')
                checked: model.get('checked')
                starred: model.get('starred')

        toggle: (e) =>
            checked = $(e.currentTarget).is(':checked')

            @modifyChannel('/todos/{{id}}', { checked: checked, timestamp: @now() })

        star: (e) =>
            @modifyChannel('/todos/{{id}}', { starred: true, timestamp: @now() })
            false

        unstar: (e) =>
            @modifyChannel('/todos/{{id}}', { starred: false, timestamp: @now() })
            false

        now: () ->
            return new Date().getTime()

        remove: (e) =>
            # FIXME
        	@view.$el.remove()
        	false

    return TodoWidget