define [], () ->
    class RawData
        constructor: ->
            _.extend(@, Backbone.Events)
            @data = {}
            @default_value = {}

        setDefaultValue: (default_value) =>
            ###
                Sets the default values for this RawData.

                default: a dictionary of the form k, v, where k is the
                        key name, and v can be either a value or a function
                Returns: nothing
            ###
            @default_value = {}
            for k, v of default_value
                if $.isFunction(v)
                    @default_value[k] = v()
                else
                    @default_value[k] = v

        setData: (data) =>
            ###
                Set the value of data
            ###
            @data = data
            @trigger('change', @)

        getData: =>
            ###
                Get the value of data
            ###
            result = _.clone(@default_value)
            _.extend(result, @data)

        toJSON: =>
            _.clone(@data)

        get: (k) =>
            ###
                Get a value of a sub-set of the data.

                k: a "path" with items separated by "/"
                Returns: the data at the given path or null

                For example, if we want to get the available languages from an
                analytics call, we can do data.get('available/languages'). This
                is somewhat similar to XPath.
            ###
            tokens = k.split('/')
            elem = @getData()
            for token in tokens
                if token of elem
                    elem = elem[token]
                else
                    return null
            elem

        set: (k, v = null) =>
            # Check it's called with the dict syntax
            if $.isPlainObject(k)
                dict = k
            # .. or with the single-key-and-value syntax
            else
                dict = {k: v}

            # Alter the internal data
            for k1, v1 of dict
                @data[k1] = v1

            # Trigger the change event - only once
            @trigger('change', @)

        unset: (k, options={}) =>
            ###
                unset an attribute
            ###
            if k of @data
                delete @data[k]
            if (options.silent != true)
                @trigger('change', @)
            @

        fetch: (options = {}) =>
            ###
                Fetches the data for this channel from a given URL.

                url: the url to fetch from (it should return JSON)
                options:
                    add: true - overwrite the current collections with a new one
                        (items with non-overlapping keys will be kept). Default
                        is to "reset" the collection (a.k.a. replace it
                        completely with the new one).
                Returns: nothing
            ###

            # Check that we know where to fetch the data from
            if not ('url' of @)
                logger.error("Can't fetch RawData from non-existing URL")
                return

            # Determine HTTP GET params
            if 'data' of options
                params = options.data
            else
                params = {}

            success_callback = (data) =>
                if not options.add?
                    @data = {}
                # Make sure that data is always a dict, even when
                # we're getting a raw text response
                if not $.isPlainObject(data)
                    data = {result: data}
                @set(data)

            # Make the actual AJAX request
            $.ajax(
                url: @url,
                dataType: 'json'
                data: params
                success: success_callback
                type: options.type || 'GET'
            )

    return RawData