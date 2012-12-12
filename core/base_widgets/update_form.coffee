define ['cs!widget/base_form', 'cs!channels_utils', 'cs!mozaic_backbone_form'], (BaseForm, channels_utils, MozaicBackboneForm) ->

    class UpdateForm extends BaseForm

        template_name: 'templates/update_form.hjs'
        render_stringified: true

        get_subscribed_channel_events: (params) =>
            ###
                Handle any incoming notification on the model's channel.
                We subscribe only to item events for ERROR, SYNC, DESTROY
                and CHANGE.
            ###
            # Receive the model that's being edited and set it to the
            # model instance variable. Create the form object and
            # render the form
            if params.type == 'change'
                if not @model?
                    unless @requiresAggregateData()
                        @model = params.model
                        @createForm()
                        @render(@render_stringified)
                else
                    if params.model.id is @model.id
                        # If the model is instantiated and a change has been
                        # been provoked on the model the widget should be closed
                        # as the edit was successfull.
                        # IMPROV: after save is used all over the place ...
                        @afterCommit(params.model)
                        @destroyForm()
            # If the event is for an error then update the layout and display
            # the server errors
            if params.type == 'error'
                # Parse errors from the jqXHR response received as the error
                # object and add them to the form errors. Enable the form
                # afterwards to let the user update the model's fields
                @parseServerErrors(params.response)
            # If the event is ADD and the model has an id attribute then the model
            # has been saved successfully and we can destroy this widget
            if params.type == 'add'
                # TODO (bogdan):
                # Update this method to include a check to see if the model received
                # via params.model is the same with @model. If this is the case
                # then we should close the modal. Otherwise we shouldn't :)
                # 1. if not params.model.isNew()
                # This check should do after update of tag endpoint
                @afterCommit(params.model)
                @destroyForm()

        get_aggregated_channel_events: (params...) =>
            # Mark this as true to prevent re-rendering the form for future calls,
            # because we have received the initial data for rendering the form.
            return if @aggregated_channel_events_call_succeeded

            return false unless super(params...)

            # FIX IN FUTURE: this is a wanted limitation for now, to prevent
            # further bugs. After base_form::get_aggregated_channel_events was
            # successfully called, don't allow form re-rendering because
            # the user could have already modified the form content, and
            # re-rendering it would mean deleting all the introduced data,
            # not necessarily existent in the model (the introduced user data is
            # saved into the form model only when the user pushes commit).
            #
            # E.g. The user adds text to post a new social post, but while doing so,
            # a required channel modifies, and causes the form re-rendering. So,
            # all user's text will be lost. To make this work, we need to somehow
            # render only a part of the form, not all of it. For now, just ignore
            # this kind of events.
            @aggregated_channel_events_call_succeeded = true

            # Create form only if you have a view where
            # to attach it to. If @view has been distroyed, don't.
            if @view
                @createForm()
                @render(@render_stringified)

            # Implement superclass interface of return true when data has been
            # received and accepted
            return true

        action: =>
            super()
            # Validate the form client side
            errors = @form.commit()
            # After commiting the form values to the form model
            # (now the form's model will have the form's values
            # set as attributes) execute an afterFormCommit callback to
            # allow us to add any additional attributes on the model
            @afterFormCommit(@form.model)
            if not errors?
                # Update the model with the form's model attributes
                # but don't trigger any events
                @model.set(@getFormModelAttributes(), { silent: true })
                # Try to create/update the model on the server
                @syncModel('update')
            else
                # Let the user correct the validation errors by
                # enabling the form
                @enableForm()

        getFormModelAttributes: ->
            return @form.model.attributes

        getFormSchemaName: ->
            ###
                Get the schema of this form. It can either be 'default' or
                a value coming in from params.
            ###
            if @model_schema? then @model_schema else 'default'

        createForm: =>
            ###
                Create a Backbone form based on the associated widget's model
                and set it on the instance variable form.
            ###

            # when no model is attached
            return unless @model

            clone = @model.clone()
            # Send the schema as an argument using model.getSchema as schema
            # callbacks for fields (like options for the Users select in Task
            # model) depend on model attributes which are not present when
            # the model is created. Execute those callbacks when there's
            # data on the model to render the fields. The holder argument is
            # a reference to the widget's view required to render custom
            # template fields (instead of letting BBF do it's magic)
            @form = new MozaicBackboneForm ({ model: clone, schema: clone.getSchema(@getFormSchemaName()), holder: @view.el })

            # Make this form available inside editors and anywhere else where
            # the Backbone form would pass its reference, by attaching a
            # reference to this form widget on the Backbone form itself
            @form.formWidget = this

        renderForm: =>
            ###
                Renders a Backbone Form bound to this widget's model
                and append the form's element to the widget's DOM
            ###
            @beforeRender(@form.model)
            @form.render()
            @afterRender(@form.model)
            $(@view.el).find(".form").append(@form.el)

        beforeRender: =>
            # allows modification of underlying model before rendering

        afterRender: =>
            # allows modification of the form or underlying model right after rendering
            # ex: use to mark as selected an <option> in a <selected> form field

        afterFormCommit: (model) =>

        destroy: =>
            super()
            # Remove cross-reference between Backbone form and form widget
            delete @form.formWidget if @form

    return UpdateForm
