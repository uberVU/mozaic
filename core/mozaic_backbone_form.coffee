define [], () ->
    
    class MozaicBackboneForm extends Backbone.Form
        ###
            An extension of Backbone forms to support rendering 
            of the form over a predefined template containing 
            fields placeholder. In your template you can define 
            a field <div data-field="{{url}}"> and when the form 
            is rendered the field will be rendered in the data-field 
            div. Overwrites the BBF custom behaviour of inserting 
            all fields in it's form element to support custom templates
        ###
        
        initialize: (options) ->
            if options.holder?
                @holder = options.holder
            else
                throw('Please provide a holder div where we will find the data-field HTML tags')
            super(options)
        
        renderFields: (fieldsToRender, $formContainer) ->
            ###
                Overwrite the renderFields method of BackboneForms to 
                wrap the rendering of custom fields. 
            ###
            # Breaking CS compiler if using super instead of an alias
            superAlias = MozaicBackboneForm.__super__.renderFields
            placeholderFields = {}
            if @holder?
                # Create a list of fields we should render in a placeholder 
                # instead of the default's BBF form tag
                for field in fieldsToRender
                    fieldContainer = $(@holder).find("[data-field=#{field}]")
                    if fieldContainer.length > 0
                        placeholderFields[field] = fieldContainer
            # Render placeholder fields in their respective container
            for fieldName, fieldContainer of placeholderFields
                superAlias.apply(this, [[fieldName], fieldContainer])
            # Render remaining non placeholder fields at once if they exist in 
            # the default BBF form tag
            unrenderedFields = _.difference(fieldsToRender, _.keys(placeholderFields))
            if unrenderedFields.length > 0
                superAlias.apply(this, [unrenderedFields, $formContainer])

    return MozaicBackboneForm