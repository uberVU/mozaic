define ['cs!widget', 'cs!model/stream'], (Widget, Stream) ->
    
    # 
    # TODO: Provide a good dispose method for closing the wizard

    class Wizard extends Widget
        
        subscribed_channels: ['/streams']
        template_name: 'templates/wizard.hjs'
        
        params_defaults:
            'model_id': 'data-params'
            
        events:
            'click #tabs li': 'toggleTab'
        
        initialize: ->
            @current_step = 0
            # Define the steps for the current wizard.
            @steps = [
                { 'title': 'Define your keywords', 'schema': 'search_expression' },
                { 'title': 'Filters & Sources', 'schema': 'filter_and_sources' }, 
                { 'title': 'Last details', 'schema': 'name_and_folder' }
            ]
            # Render each step in the layout 
            # After each completed step move the wizard to the next step
            params = {
                steps: @steps
            }
            @renderLayout(params)
            @setup()
            @insertStepWidget()
            @createTabs()
            
        setup: () ->
            @currentStepEl = @el.find('#current-step')
            
        isNew: ->
            ###
                If we are editing a model return false, otherwise (we're 
                adding a new object) return true
            ###
            not @model_id?
            
        setStepFormParams: (schema) ->
            model_form_params =
                model_path: 'cs!model/stream'
                model_schema: schema
                channel_key: 'streams'
                required_channels: [ 
                    { channel: '/folders', model_attribute: 'folders', sync: false }
                ]
                channels:
                    '/streams': @channel_mapping['/streams']
                    '/folders': @channel_mapping['/folders']
            # If there's already a model_id then we are performing an 
            # edit and we should add it to the widget's params
            if @model_id?
                model_form_params['model_id'] = @model_id
                # Add the model's channel as the first required channel. 
                # We have to aggregate data from this channel when performing 
                # an edit
                model_form_params['required_channels'].splice(0, 0, { 'channel': '/streams/' + @model_id, 'model_attribute': '.', 'sync': false })
            return model_form_params

        insertStepForm: (step) ->
            ###
                Insert a form for a step of the form. Construct params for 
                injecting the form in the page
            ###
            model_form_params = @setStepFormParams(@steps[step]['schema'])
            Utils.injectWidget(@currentStepEl, 'form', model_form_params, null, true, null, false)

        insertStepWidget: ->
            ###
                Advance to the next step of the wizard unless we've reached 
                the end of if
            ###
            if @current_step is @steps.length
                @destroyWizard()
            else
                # Insert this step
                @insertStepForm(@current_step)
                
        createTabs: ->
            ###
                Create the tabs for the wizard based on the 
                current state of the wizard. How this works:
                If this is a wizard for a new model create 
                tabs up to the current_step. The rest of the 
                tabs are disabled
                If this is a wizard for an existing model then 
                just create tabs.
            ###
            tabHolder = $('#tabs')
            for step, index in @steps
                tabElement = @addTab(index)
                tabHolder.append(tabElement)
            
        toggleTab: (event) =>
            ###
                Clicking on a enabled tab should take you 
                to the tab. Inject the form of this step
            ###
            element = $(event.currentTarget)
            # Find out the step we are in
            step = parseInt(element.data('step'))
            # If this is the current step, do nothing
            unless step is @current_step
                # We have to toggle this tab if the 
                # step is toggable
                if element.hasClass('enabled')
                    @current_step = step
                    @insertStepForm(step)
            return false
                    
                    
        stepTabEnabled: (index) ->
            ###
                The state of the step tab at index. If 
                the form is new then 
            ###
            if @isNew() and index > @current_step
                return false
            return true
                    
        addTab: (index) ->
            ###
                Add a tab in the tabs holder. A tab has a title and 
                a state (disabled or enabled). Hold the step of the 
                tab inside the id of the element
            ###
            # Set the id of the tab
            id = 'step-' + index
            # Set the css class of the tab (either enabled or disabled) and 
            # add a selected class if this tab is selected. 
            css_class = if @stepTabEnabled(index) then 'enabled' else 'disabled'
            if index is @current_step
                css_class += ' selected'
            # Template of the tab
            template = '<li id="{{id}}" class="{{css_class}}" data-step="{{index}}">{{title}}</li>'
            # Set template params
            params = {
                index: index
                id: id
                css_class: css_class
                title: @steps[index]['title']
            }
            # Render the tab template
            compiled_template = Handlebars.compile(template)
            template = compiled_template(params)
            return template

        get_streams: (params) ->
            ###
                If a stream was added to the list of streams from a form (
                # there can be only one form opened at a certain moment on 
                # the page) then get to the next step
            ###
            if params.type is 'add'
                # The model was saved using the first step of the wizard
                if params.model.get('form')
                    @model_id = params.model.id
                    # We should get to the second step using
                    @current_step += 1
                    @insertStepWidget()
            # Listen to change events to know when we should 
            # advance to the next step of the wizard if the changed 
            # model is the one being edited
            if params.type is 'change'
                # Verify if the changed model is the model we are working 
                # with in this widget
                if params.model.id == @model_id
                    @current_step += 1
                    # Insert the next step of the wizard
                    @insertStepWidget()
                    
        destroyWizard: () =>
            ###
                Close the wizard
            ###
                

    return Wizard