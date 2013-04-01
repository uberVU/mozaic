define [], () ->

    class WidgetEditor extends Backbone.Form.editors.Base
        ###
            The Widget Editor is a BBF Editor-compatible Widget wrapper,
            that has a Mozaic widget attached that it controls.

            The idea is to have most of the logic in the attached widget
            and avoid extending this widget altogether.
        ###
        template: '<div class="mozaic-widget" data-widget="{{widget_name}}" data-params="{{widget_params}}"></div>'

        initialize: (options) ->
            super(arguments...)
            # A widget name in the model schema is required for this
            # to work
            @widget_name = @schema.widget_name
            unless @widget_name?
                throw new Error 'Editor has no widget name assigned'

            # Support a default value for when the editor has not yet
            # initialized
            @default_value = @schema.default_value or null
            # Default widget params can be specified in the model schema
            # as well, as a starting point
            @widget_params = @schema.widget_params or {}
            # Additional widget params are taken from the form template,
            # which are actually set to the field's div
            _.extend(@widget_params, @_getParamsFromEditorField())
            # The value must always be passed to the editor widget
            @widget_params.value = @value
            # Pass on options for select-like editors
            if @schema.options?
                options = @schema.options
                if _.isFunction(options)
                    options (result) =>
                        # XXX does not support async populating
                        @widget_params.options = result
                else
                    @widget_params.options = options

        _getParamsFromEditorField: () ->
            ###
                Get data-params from editor's parent _field_.
            ###
            # The field nor the editor templates are not yet bound to
            # the form DOM so a relative jQuery path cannot be used.
            editorField = $('[data-field=' + this.key + ']')
            return editorField.data('params') or {}

        render: () ->
            ###
                Before rendering, start listening to the "/new_widget"
                pubsub channel, in order to grab the new-born widget
                as soon as it takes life. @see #newWidget

                Then, render a widget div as the editor output, and let
                the loader handle its initiation and manage its entire
                existance and garbage collection from that point on.
            ###
            @pipe = loader.get_module('pubsub')
            @pipe.subscribe('/new_widget', @newWidget)

            # Compile and render widget container template
            template = Handlebars.compile(@template)
            @$el.html template(
                widget_name: @widget_name
                widget_params: JSON.stringify(@widget_params)
            )
            return this

        newWidget: (message) =>
            ###
                Whenever a new widget is announced, we check to see
                it is the one created by this editor, by matching its
                name against the editor's assigned widget_name and then
                by matching its id against _mozaic-widget_ child nodes.

                As soon as _the one_ is intercepted we store it locally
                and remove this handler altogether.
            ###
            return if message.name isnt @widget_name
            widget_id = message.widget.params.widget_id
            if @$el.find("[data-guid=#{widget_id}]").length
                @widget = message.widget
                @pipe.unsubscribe('/new_widget', @newWidget)
                # Create a back-reference to editor in widget
                @widget.editor = this
                # Call initializeWithForm method on editor, if one is
                # implemented
                if _.isFunction(@widget.initializeWithForm)
                    @widget.initializeWithForm(@form)

        getValue: () ->
            return if @widget? then @widget.getValue() else @default_value

        setValue: (value) ->
            @value = value
            @widget?.setValue(@value)

            # Keep form model up to date with editor values
            if @schema.sync_form_model and not @formHasValue(value)
                @form.model.set(@key, @getValue(), silent: true)
                # After we update the editor's corresponding model value, go
                # through all the other from editors (but this one), and update
                # their value with the one in the model. This is useful because
                # changing a model attribute might change other ones as well,
                # thus having more logic inside the models.
                for key, field of @form.fields
                    continue if key is @key
                    editor = field.editor
                    modelValue = @form.model.get(key)
                    # Since the Underscore check is strict we need to make sure
                    # null and undefined values are loosely compared, so the
                    # modalValue need to be null if missing. This avoids a lot
                    # of pointless assignments and hook triggerings
                    modelValue = null unless modelValue?
                    unless _.isEqual(modelValue, editor.getValue())
                        editor.setValue(modelValue)

            @notifyModelChanged(value)

        notifyModelChanged: (value) ->
            ###
                Check for form hooks that listen to model changes and trigger
                them if defined
            ###
            if _.isFunction(@form.formWidget?.modelChanged)
                @form.formWidget.modelChanged(@key, value)

        formHasValue: (value) ->
            ###
               Check if the editor value is equal with the current one inside
               the form.
               Match null and undefined as equal though, since they both
               represent missing values
            ###
            formValue = @form.model.get(@key)
            # Strict comparison (===)
            return true if value is formValue
            # If they're not strictly equal and one of the is defined, then
            # they're not equal
            return false if value? or formValue?
            # At this point they're both null/undefined
            return true
