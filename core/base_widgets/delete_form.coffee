define ['cs!widget/base_form'], (BaseForm) ->

    class DeleteForm extends BaseForm

        template_name: 'templates/delete_form.hjs'
        render_stringified: true

        constructor: (params...) ->
            # Set a default delete message to be yielded in the template
            @message = 'Are you sure you want to delete this object?'
            super(params...)

        get_subscribed_channel_events: (params) =>
            ###
                Handle any incoming notification on the model's channel.
                We subscribe only to item events for ERROR, SYNC, DESTROY
                and CHANGE.
            ###
            # Receive the model that will be deleted and set it to the
            # model instance variable. Render the layout after the object
            # has arrived, unless it requires aggregate data
            if params.type == 'change'
                @model = params.model
                unless @requiresAggregateData()
                    @render()
            # Wait for a SYNC event on the model to acknowledge the successful
            # removal of the model from the server
            if params.type == 'sync'
                # Execute the after commit callback
                @afterCommit(@model)
            # If the event is for an error then update the layout and display
            # the server errors
            if params.type == 'error'
                # Parse errors from the jqXHR response received as the error
                # object and add them to the form errors. Enable the form
                # afterwards to let the user update the folder fields
                # TODO: We might want to move this out to the datasource
                @parseServerErrors(params.response)
            if params.type == 'destroy'
                # The destroy of the model is successful. We should close
                # this widget
                @afterCommit()
                @destroyForm()

        get_aggregated_channel_events: (params) =>
            for event, i in params
                if not (event.type in ['reset', 'change'])
                    return
            super(params)
            @render()

        action: =>
            super()
            @syncModel('delete')

        render: ->
            ###
                Renders the layout and the associated form object if
                present. You can customize the delete message by sending
                a message in the form's default params, otherwise using
                the default message set in constructor
            ###
            params =
                message: if @params.message? then @params.message else @message
                yes_text: @params.yes_text or 'Yes'
                no_text: @params.no_text or 'No'
                model: @model.toJSON()
            @renderLayout(params, @render_stringified)

    return DeleteForm
