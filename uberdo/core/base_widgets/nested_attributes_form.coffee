define ['cs!widget/update_form'], (UpdateForm) ->

    class NestedAttributesForm extends UpdateForm
        ###
            An update form that supports nested attributes. They are flattened
            when being rendered as namespace__key, and get sent to (and received
            from) the server as a nested JSON {namespace:{key:...}}.
        ###
        beforeRender: (model) =>
            super(model)
            # Flatten model attributes because form doesn't support them nested
            @flattenAttributes(flatAttributes = {}, model.toJSON())
            model.clear(silent: true)
            model.set(flatAttributes, silent: true)

        getFormModelAttributes: ->
            # Nest previously flattened attributes into their original form
            # before sending them back to the server (but without affecting
            # the actual model instance)
            return @nestAttributes(super())

        flattenAttributes: (data, attributes, keyPrefix = '') =>
            ###
                Flatten nested object into a one-level object with concatenated
                keys.

                The flattening convention is to add `__` (two underscores) for
                each of the nested levels.

                The flat data object is populated recursively, by passing its
                reference through each call, along with a current subset of
                attributes and relevant key prefix.

                Example:
                    nestedObject = {foo: {bar: true}}
                    @flattenAttributes(flatObject = {}, nestedObject)
                    console.log(flatObject) # outputs {foo__bar: true}

                @param {object} data Output flat object
                @param {object} attributes Current subset of attributes
                @param {string} keyPrefix Current key prefix
                @see #nestAttributes
            ###
            for k, v of attributes
                # We only need to flatten plain objects, because models might
                # have entire collections attached to them, and we don't want
                # to flatten those, especially because they have circular
                # dependencies and would create infinite loops
                if $.isPlainObject(v)
                    # Append key to key prefix and carry on to a new recursive
                    # call for this specific (nested) subset of attributes
                    @flattenAttributes(data, v, "#{keyPrefix}#{k}__")
                else
                    # Add value into main data object, using current key prefix
                    data["#{keyPrefix}#{k}"] = v

        nestAttributes: (attributes) ->
            ###
                Nest previously flattened object into a nested object.

                The flattening convention is to add `__` (two underscores) for
                each of the nested levels.

                Example:
                    nestedObject = @nestAttribute({foo__bar: true})
                    console.log(nestedObject) # outputs {foo: {bar: true}}

                @param {object} attributes Flat attributes to nest
                @return {object} Nested attributes
                @see #flattenAttributes
            ###
            data = {}
            for k, v of attributes
                subset = data
                keys = k.split('__')
                # Navigate through the extra key parts to create the nested
                # structure, before adding the current value to its relevant key
                while keys.length > 1
                    key = keys.shift()
                    # Create subset if this is the first time we get to it
                    subset[key] = {} unless subset[key]
                    subset = subset[key]
                subset[keys.shift()] = v
            return data
