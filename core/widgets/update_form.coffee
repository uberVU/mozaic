define ['cs!widget/base_form', 'cs!channels_utils', 'cs!uber_backbone_form'], (BaseForm, channels_utils, UberBackboneForm) ->

    class UpdateForm extends BaseForm
        
        template_name: 'templates/update_form.hjs'
        
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
                        @render()
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
            return unless super(params...)
            # Create form only if you have a view where
            # to attach it to. If @view has been distroyed, don't.
            if @view
                @createForm()
                @render()
            
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
                @model.set(@form.model.attributes, { silent: true })
                # Try to create/update the model on the server
                @syncModel('update')
            else
                # Let the user correct the validation errors by 
                # enabling the form
                @enableForm()
            
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
            clone = @model.clone()
            # Send the schema as an argument using model.getSchema as schema 
            # callbacks for fields (like options for the Users select in Task 
            # model) depend on model attributes which are not present when 
            # the model is created. Execute those callbacks when there's 
            # data on the model to render the fields. The holder argument is 
            # a reference to the widget's view required to render custom 
            # template fields (instead of letting BBF do it's magic)
            @form = new UberBackboneForm ({ model: clone, schema: clone.getSchema(@getFormSchemaName()), holder: @view.el })
            
        renderForm: =>
            ###
                Renders a Backbone Form bound to this widget's model 
                and append the form's element to the widget's DOM
            ###
            @form.render()
            $(@view.el).find(".form").append(@form.el)
            
        afterFormCommit: (model) =>

    return UpdateForm
