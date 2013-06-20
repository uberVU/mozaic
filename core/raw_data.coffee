define [], () ->
    class RawData
        collection_type: 'api'

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

        getData: (return_default_data = true) =>
            ###
                Get the value of data. If return_default_data is false we ignore
                the default values. An use-case is the date-filter.
            ###
            result = if return_default_data then _.clone(@default_value) else {}
            _.extend(result, @data)

        toJSON: =>
            _.clone(@data)

        get: (key) =>
            ###
                Returns: the data at the given path or null

                For example, if we want to get the available languages from an
                analytics call, we can do data.get('available/languages'). This
                is somewhat similar to XPath.
            ###
            return Utils.getNestedAttr(@getData(), key)

        has: (key) =>
            return key in _.keys(@getData())

        set: (k, v = null, options = {}) =>
            # Check it's called with the dict syntax
            if $.isPlainObject(k)
                dict = k
            # .. or with the single-key-and-value syntax
            else
                dict = {}
                dict[k] = v
            @_internal_set(dict, options)

            return this

        _internal_set: (dict, options) =>
            previousData = _.clone(@data)

            if options.reset or options.new_data
                @data = {}

            # Alter the internal data
            for k, v of dict
                @data[k] = v

            changed_attributes = @_getChanged(previousData)

            # Before triggering reset/change events
            # we need to handle datasource logic when fetching channel data
            # like setting last_fetch timestamp
            # Fetched event hook was also defined in backbone collection
            options.fetched() if options.fetched?

            # Trigger the change event - only once
            if options.silent != true

                # If this was a complete reset of the RawData,
                # trigger the reset event
                if options.reset
                    # The changed attributes are ALL the attributes in this
                    # case, but it might be OK to have a consistent signature,
                    # but also, since the events are async, it might be helpful
                    # to know these attributes in the event callback since the
                    # model could already have been altered at that point
                    @trigger('reset', @, changed_attributes)
                # Otherwise, trigger the change event.
                else
                    @trigger('change', @, changed_attributes)

        unset: (dict, options={}) =>
            ###
                unset an attribute
            ###
            previousData = _.clone(@data)

            for k, v of dict
                if k of @data
                    delete @data[k]

            changed_attributes = @_getChanged(previousData)

            if (options.silent != true)
                @trigger('change', @, changed_attributes)

            return this

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

            success_callback = (data, response_status) =>
                if not options.add?
                    @data = {}
                # Make sure that data is always a dict, even when
                # we're getting a raw text response
                if not $.isPlainObject(data)
                    data = {result: data}

                @set(data, null, {new_data: true, fetched: options.fetched})
                # Trigger a sync event (similar to Backbone's sync event)
                @trigger('sync', @)
                # Also call the success callback.
                options.success(@, response_status) if options.success
                # Trigger a no_data event when the response is empty
                if _.isEmpty(data)
                    @trigger('no_data', @)

            error_callback = (xhr, response_status, error_string) =>
                # Trigger an 'error' event when the request results in an error
                # (including 3xx redirect and timeouts).
                # This is important because we need to have a response from
                # widgets on error events.
                @trigger('error', @, @, xhr.status)

            # Make the actual AJAX request
            call_params =
                url: @url
                dataType: 'json'
                data: params
                success: success_callback
                error: error_callback
                type: options.type || 'GET'

            # If we are passed contentType, pass it through
            if options.contentType
                call_params.contentType = options.contentType

            $.ajax(call_params)

        _getChanged: (previousData) ->
            ###
                Compare a previous set of data and establish the changed
                attributes between the two
            ###
            changed = {}
            # Get the union of all attribute keys from both the previous and
            # the current data set
            for k in _.union(_.keys(previousData), _.keys(@data))
                # Only mark attributes with different values as changed
                changed[k] = @data[k] if @data[k] isnt previousData[k]
            return changed

    return RawData
