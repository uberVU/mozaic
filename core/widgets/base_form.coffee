define ['cs!widget', 'cs!channels_utils'], (Widget, channels_utils) ->

    class BaseForm extends Widget
        
        ###
            Execute the afterCommit event in your child classes
            Render only executes if the model is new and doesn't 
            requires aggregateData
            
            TODO (bogdan): perform arguments checking for channel_key, model_path
        ###

        params_defaults:
            'model_id': 'data-params'
            'model_path': 'data-params'
            'model_schema': 'data-params'
            'model_sync': true
            'channel_key': 'data-params'
            'required_channels': 'data-params'
            # Whether we should destroy the form 
            # after the commit has been performed
            'destroy_after_commit': true
        
        events:
            "click .commit": "commit"
            "click .cancel": "cancel"
            "click .toggle": "toggle"

        initialize: ->
            @setup()
            # Render the form if the model is new and 
            # doesn't require aggregate data
            if @isNew()
                unless @requiresAggregateData()
                    @setModel()
                    @createForm()
                    @render()
            
        setup: ->
            ###
                Execute setup methods for:
                - the loading of the model class
                In the load callback execute the following
                - setting subscribed_channels
                - setting aggregated_channels
            ###
            @loadModelClass(=>
                if @checkRequiredChannels()
                    @subscribeDataChannels()
                    @subscribeAggregateDataChannels()
            )

        loadModelClass: (callback) ->
            # Load model class via require. The model_path contains  
            # the path of the model class and we set @model_class 
            # in the load callback
            require [@model_path], (model_class) =>
                @model_class = model_class
                callback()
    
        checkRequiredChannels: ->
            ###
            TODO
            ###
            return true
                    
        requiresAggregateData: ->
            ###
                Return true if the model requires data from other channels
                (like task requiring users). Returns false otherwise (like 
                folder that doesn't depend on anything)
            ###
            if @required_channels?
                return @required_channels.length > 0
            return false
        
        subscribeDataChannels: ->
            ###
                This widget handles the edit and new actions of a  model. 
                If the model is new then we should subscribe 
                to the '/folders' channel. Otherwise subscribe to the 
                '/folders/{{folder_id}}' channel. 
                Also setup aggregated channels for additional data that 
                is required in the form rendering process. 
            ###
            if @isNew()
                @subscribed_channels = [channels_utils.formChannel(@channel_key)] 
            else
                @subscribed_channels = [channels_utils.formChannel(@channel_key, @model_id)]
            # Setup subscribed channel handler (like /folders for a folder form)
            @["#{channels_utils.widgetMethodForChannel(@, @channel_key)}"] = @get_subscribed_channel_events
            # Setup aggregated channel handler for all required data for the form 
            # that's on other channels
            if @requiresAggregateData()
                # In order for an aggregate method to work we need to supply 
                # the aggregated channels as subscribed channels, even if 
                # we don't need their events. Ex: assuming we require streams 
                # for the new folder form, besides folders. The form is subscribed 
                # by default to folders, but not on streams (no need for the data). 
                # Create an anonymous method for the missing aggregated channel 
                # and add it to the subscribed channels
                for data in @required_channels
                    # Don't subscribe twice to a channel
                    if not (data.channel in @subscribed_channels)
                        @subscribed_channels.push(data.channel)
                            
        subscribeAggregateDataChannels: ->
            ###
            ###
            if @requiresAggregateData()
                @aggregated_channels = 
                    get_aggregated_channel_events: (data.channel for data in @required_channels)

        get_subscribed_channel_events: (params) =>
            ###
                Handle any incoming notification on the subscribed's model channel.
                Overwrite this method in your forms
            ###
                    
        get_aggregated_channel_events: (params...) =>
            ###
                Handler for all data required by the form (like users or 
                mentions) to render. For example, a task needs users and 
                the mention of the task to render (a save form). A folder 
                might need it's streams to display the form (a delete form).
                Setup a single aggregated channel for all @required_channels.
            ###
            # Ignore events that are not reset or change. This method is used to 
            # bootstrap the form with required data. It's outside the scope of this 
            # widget to keep the initial bootstrapped data up to date. Ex: Adding 
            # a new task requires the list of users. After we get the initial list 
            # a new user might be added and the form has to be rendered again. Will 
            # loose any user input if we handle this case. 
            for event, i in params
                if not (event.type in ['reset', 'change'])
                    return false
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
                @setModel()
            else
                @model = aggregated_results[0]
            # For each aggregated event set either collection or model of the 
            # event on the model instance of the form. The attribute that will 
            # be set on the model is given as model_attribute of an item 
            # from required_channels.
            # required_channels: [{ channel: '/users', model_attribute: 'users', sync: false }]
            for k, v of aggregated_results
                unless @required_channels[k].model_attribute is '.'
                    @model.set(@required_channels[k].model_attribute, v, { silent: true })
        
        isNew: ->
            ###
                If we are editing a model return false, otherwise (we're 
                adding a new folder) return true
            ###
            not @model_id?

        setModel: (model = null) =>
            @model = if model? then model else new @model_class()
            # Set a 'form' attribute on the model. This way we know 
            # in other widgets when a model was modified via a 
            # form
            @model.set('form', true, { silent: true })
            
        syncModel: (mode = 'update') ->
            ###
                Save (or delete, based on the mode argument) the model 
                associated with the form
            ###
            # Decide what operation (create or update) we should perform 
            # on the model by inspecting it's id property (via isNew). If it's 
            # not present then perform a save, otherwise an update via 
            # addChannel or modifyChannel (widget.coffee)
            switch mode
                when 'update'
                    if @model.isNew()
                        @addChannel(channels_utils.formChannel(@channel_key), 
                                    @model.attributes, 'append', false, @model_sync)
                    else
                        channel = channels_utils.formChannel(@channel_key, @model.id)
                        @modifyChannel(channel, @model.attributes, 'append', 
                                       false, @model_sync)
                when 'delete'
                    @deleteChannel(channels_utils.formChannel(@channel_key, @model.id))

        render: ->
            ###
                Renders the layout and the associated form object if 
                present.
            ###
            @renderLayout(if @model? then @model.toJSON() else {})
            if @form?
                @renderForm()
            
        beforeCommit: (model) =>
            ###
                Execute this callback before saving a model (
                before submitting a form). Disable form first and 
                do any custom work in your child classes.
            ###
            @disableForm()

        commit: (event) =>
            ###
                Perform form validation and submission. First perform 
                client side validation via @form and then send the 
                data to the server and wait for server side errors.
            ###
            if @form?
                @beforeCommit(@form.model)
            else
                @beforeCommit(@model)
            # Disable the form during the entire process. Form 
            # is explicitely enabled when the model has been 
            # synced on server
            @action()

        action: () =>
            ###
                This is the base action that's executed in the commit 
                step of the form. This method should be overwritten in 
                child classes.
            ###

        afterCommit: (model) =>
            ###
                Execute this callback after the form has been saved. 
                Receives a model argument (this can be improved by 
                setting @model = model received from subscribed channels
                after a save or edit). Enable the form after the commit
                has been performed.
            ###
            @enableForm()
            
        parseServerErrors: (response) ->
            ###
                Parse server errors from a jQuery response object 
                and add them on the form
            ###
            try
                errors = JSON.parse(response.responseText)
                if errors.errors?
                    @addFormErrors(errors.errors)
            catch exception
                logger.error(exception)
            finally
                @enableForm()
                
        createForm: ->
            ###
                Creates a form object from the provided model using 
                the given out schema and attaches it to this widget
            ###
            
        formHTMLElements: ->
            ###
                Return the list of all elements in the form: input elements and 
                submit buttons
            ###
            # Select all input, select and textarea (form) fields
            inputElements = $(@view.el).find('input,select,textarea')
            # We might use buttons (not inputs) for submit elements. 
            commitElements = $(@view.el).find('button.commit')
            return _.union(inputElements, commitElements)
            
        disableForm: ->
            ###
                Any form enters a disabled state after the 
                submit button has been pressed. All fields 
                of the form are disabled and the label of 
                the submit button will be changed to "Saving"
            ###
            # Disable all input elements and also add a disabled class
            for el in @formHTMLElements()
                el.prop('disabled', true).addClass('disabled')

        enableForm: ->
            ###
                Enable the form by resetting the label of submit 
                button to "Save" and enabling all fields
            ###
            # Enable all input elements and remove any disabled class
            for el in @formHTMLElements()
                el.prop('disabled', false).removeClass('disabled')
            
        destroyForm: ->
            ###
                Dispose this form by deleting this widget.
                # TODO: dispose the form attrribute in destroyForm
            ###
            if @destroy_after_commit? and @destroy_after_commit
                Utils.closeModal()

        cancel: (event) ->
            Utils.closeModal()
            return false
            
        addFormErrors: (errors) ->
            ###
                Display form errors

                errors is a dictionary of this form:
                { '__all__': ['Error message one',], 'name': ['Name is required'] }
            ###
            if '__all__' of errors
                $(@view.el).find('.errors').html(errors['__all__'].join(". "))
            for field, e of errors
                if field != '__all__'
                    @addFieldErrors(field, e)

        addFieldErrors: (field, errors) ->
            ###
                Add errors (received from the server) to the fields of 
                the form by using the Backbone.Form instance (using setError 
                on a form field). If there's no form on the object then 
                the field errors won't be displayed!
            ###
            error = errors.join('. ')
            if @form?
                # If the field received as the error field 
                # is defined in the form
                if field of @form.fields
                    @form.fields[field].setError(error)

        clearFormErrors: ->
            ###

            ###
            @view.$el.find('.errors').empty()

        toggle: (e) =>
            ###
                Toggle fields

                Links with the "toggle" class with toggle
                the visibility of certain fields from the
                form.

                The name of fields must be found inside the
                anchor's data-toggle attribute, and can be
                one or a list of space-separated fields.
            ###
            names = String($(e.currentTarget).data('toggle')).split(' ')

            for name in names
                if @form.fields[name]
                    @form.fields[name].$el.parent().toggle('fast')
            false

    return BaseForm