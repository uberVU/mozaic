define ['cs!widget', 'cs!channels_utils'], (Widget, channels_utils) ->
    
    # TODO:
    # - Sync a task with tastypie (- sync json of mention with the server)
    # - Disable and enable form methods
    # - Complete a task
    # - Listen to sync and disable form or display a loading
    # - Known bug: when trying to sync an updated model, the local
    # copy of the model get's updated in the datasource as well
    # even if the save was not successfull
    
    ###
        The form has an instance of the model that's being added/edited attached.
        The model can be a new model or an existing model and it can depend on 
        other data channels. Where do we perform object instantiation?
        If the model depends on other channels then perform the instantiation 
        in get_aggregated_channels_events. Otherwise (Doesn't depend on other data) 
        if the model is new instantiate from initialize / if the model exists 
        instantiate from subscribed
    ###

    class Form extends Widget
        template_name: 'templates/form.hjs'
        params_defaults:
            'model_id': 'data-params'
            'model_path': 'data-params'
            'model_schema': 'data-params'
            'channel_key': 'data-params'
            'required_channels': 'data-params'
        events:
            "click input[type=submit]": "save"

        initialize: ->
            @setup()
            @subscribeChannels()
            
        setup: ->
            # Load model class via require. The model_path contains  
            # the path of the model class and we set @model_class 
            # in the load callback
            require [@model_path], (model_class) =>
                @model_class = model_class
            
            # If this is a new form create the model and the form for this
            # widget. Otherwise wait for the model to arrive via 
            # it's subscribed channels and create the form then
            if @isNew()
                unless @requiresAggregateData()
                    @createModel()
                    @createForm()
                    @render()
                    
        requiresAggregateData: ->
            ###
                Return true if the model requires data from other channels
                (like task requiring users). Returns false otherwise (like 
                folder that doesn't depend on anything)
            ###
            if @required_channels?
                return @required_channels.length > 0
            return false
        
        subscribeChannels: ->
            ###
                This widget handles the edit and new actions of a  model. 
                If the model is new then we should subscribe 
                to the '/folders' channel. Otherwise subscribe to the 
                '/folders/{{folder_id}}' channel. 
                Also setup aggregated channels for additional data that 
                is required in the form rendering process. 
            ###
            @subscribed_channels = if @isNew() then [@formChannelKey()] else [@formChannelKey() + '/' + @model_id]
            # Setup subscribed channel handler (like /folders for a folder form)
            @["#{channels_utils.widgetMethodForChannel(@, @channel_key)}"] = @get_subscribed_channel_events
            # Setup aggregated channel handler for all required data for the form 
            # that's on other channels
            if @required_channels? and @required_channels.length > 0
                # In order for an aggregate method to work we need to supply 
                # the aggregated channels as subscribed channels, even if 
                # we don't need their events. Ex: assuming we require streams 
                # for the new folder form, besides folders. The form is subscribed 
                # by default to folders, but not on streams (no need for the data). 
                # Create an anonymous method for the missing aggregated channel 
                # and add it to the subscribed channels
                for data in @required_channels
                    if not (channels_utils.widgetMethodForChannel(@, data.channel) of @)
                        if not (data.channel in @subscribed_channels)
                            @subscribed_channels.push(data.channel)
                @aggregated_channels = 
                    get_aggregated_channel_events: (data.channel for data in @required_channels)

        get_subscribed_channel_events: (params) =>
            ###
                Handle any incoming notification on the folders channel. 
                We subscribe to both collection events or item events 
                depending on the action of the widget (new or edit).
                Listen to ERROR, ADD and CHANGE events for the widget's model.
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
                        @afterSave(params.model)
                        @destroyForm()
            # If the event is for an error then update the layout and display  
            # the server errors
            if params.type == 'error'
                # Parse errors from the jqXHR response received as the error 
                # object and add them to the form errors. Enable the form 
                # afterwards to let the user update the folder fields
                # TODO: We might want to move this out to the datasource
                try
                    errors = JSON.parse(params.response.responseText)
                    @addFormErrors(errors.errors)
                catch exception
                    logger.error(exception)
                finally
                    @enableForm()
            # If the event is ADD and the model has an id attribute then the model 
            # has been saved successfully and we can destroy this widget
            if params.type == 'add'
                # TODO: 
                # Handle only events that are received for the widget's model 
                # by veryfing it's model.cid. If the model hasn't been received
                # then ignore this check
                # if @model? and params.model? 
                #     if @model.cid != params.model.cid
                #         'bla'
                if not params.model.isNew()
                    # TODO: Calling destroy from the widget might be bad practice
                    # Eventually widget_starter will clean up the stale widgets
                    @afterSave(params.model)
                    @destroyForm()
                    
        get_aggregated_channel_events: (params...) =>
            ###
                Handler for all data required by the form (like users or 
                mentions) to render. For example, a task needs users and 
                the mention of the task to render. Setup a single aggregated 
                channel for all @required_channels.
            ###
            # TODO: Don't discard all aggregated events after the model is set,
            # maybe we want to add a new user to the select in tasks, etc ...
            if @model?
                return
            # For each aggregated event set either collection or model of the 
            # event on the model instance of the form. The attribute that will 
            # be set on the model is given as model_attribute of an item 
            # from required_channels.
            # required_channels: [{ channel: '/users', model_attribute: 'users', sync: false }]
            aggregated_results = {}
            for event, i in params
                # There are two types of relational channels we can subscribe 
                # to: collection and model (still collection). Events for 
                # collections are coming in as reset and have a collection attribute
                # and for models the event is change and has a model attribute. 
                # Determine which object (collection or model) from the event 
                # payload we should set on the form's model
                if event.type is 'reset'
                    aggregated_results[i] = event.collection
                if event.type is 'change'
                    aggregated_results[i] = event.model
            # Before setting the associated data from other channels we must have a model.
            # If the form is not new, the model will come in from the required_channels. 
            # The model will be on the first position of the aggregated_results
            if @isNew()
                @createModel()
            else
                @model = aggregated_results[0]
            for k, v of aggregated_results
                unless @required_channels[k].model_attribute is '.'
                    @model.set(@required_channels[k].model_attribute, v)
            @createForm()
            @render()
        
        isNew: ->
            ###
                If we are editing a model return false, otherwise (we're 
                adding a new folder) return true
            ###
            not @model_id?

        createModel: =>
            @model = new @model_class()
            # Set a 'form' attribute on the model. This way we know 
            # in other widget when a model was saved via a form
            @model.set('form', true, { silent: true })
            
        syncModel: ->
            ###
                Save the model associated with the form after 
                the form has been validated. 
            ###
            # Decide what operation (create or update) we should perform 
            # on the model by inspecting it's id property (via isNew). If it's 
            # not present then perform a save, otherwise an update via 
            # addChannel or modifyChannel (widget.coffee)
            if @model.isNew()
                @addChannel(@formChannelKey(), @model.attributes)
            else
                @modifyChannel(@formChannelKey() + '/' + @model.id, @model.attributes)
                
        formChannelKey: () ->
            '/' + @channel_key
            
        render: ->
            ###
                Renders the layout and the associated form object if 
                present.
            ###
            @renderLayout()
            if @form
                @renderForm()
                
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
            # data on the model to render the fields.
            @form = new Backbone.Form ({ model: clone, schema: clone.getSchema(@getFormSchemaName()) })

        renderForm: =>
            ###
                Renders a Backbone Form bound to this widget's model 
                and append the form's element to the widget's DOM
            ###
            @form.render()
            $(".form").append(@form.el)
            
        beforeSave: () =>
            ###
                Execute this callback before saving a model (
                before submitting a form)
            ###

        save: (event) =>
            ###
                Perform form validation and submission. First perform 
                client side validation via @form and then send the 
                data to the server and wait for server side errors.
            ###
            @beforeSave()
            # Disable the form during the entire process. Form 
            # is explicitely enabled when the model has been 
            # synced on server
            @disableForm()
            # Validate the form client side
            errors = @form.commit()
            if not errors?
                # Update the model with the form's model attributes 
                # but don't trigger any events
                @model.set(@form.model.attributes, { silent: true })
                # Try to create/update the model on the server
                @syncModel()
            else
                # Enable the form to allow the user to update the 
                # form's value based on error suggestions
                @enableForm
        
        afterSave: (model) =>
            ###
                Execute this callback after the form has been saved. 
                Receives a model argument (this can be improved by 
                setting @model = model received from subscribed channels
                after a save or edit)
            ###
            
        disableForm: ->
            ###
                Any form enters a disabled state after the 
                submit button has been pressed. All fields 
                of the form are disabled and the label of 
                the submit button will be changed to "Saving"
            ###

        enableForm: ->
            ###
                Enable the form by resetting the label of submit 
                button to "Save" and enabling all fields
            ###
            
        addFormErrors: (errors) ->
            ###
                Display form errors
                
                errors is a dictionary of this form:
                { '__all__': ['Error message one',], 'name': ['Name is required'] }
            ###
            if '__all__' of errors
                $('.errors').html(errors['__all__'].join(". "))
            @addFieldErrors(field, e) for field, e in errors when field not '__all__'
        
        addFieldErrors: (field, errors) ->
            ###
                Add errors (received from the server) to the fields of 
                the form by using the Backbone.Form instance (using setError 
                on a form field)
            ###
            error = errors.join('. ')
            @form.fields[field].setError(error)
            
        clearFormErrors: ->
            ###
                
            ###
            @el.find('.errors').empty()
            
        destroyForm: ->
            ###
                Dispose this form by deleting this widget.
                # TODO: dispose the form attrribute in destroyForm
            ###

    return Form