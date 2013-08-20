define [], () ->
    class BaseCollection extends Backbone.Collection
        collection_type: 'relational'

        trigger_no_data: =>
            @trigger('no_data', this)

        parse: (response) ->
            ###
                Only pass on the objects attribute from the response,
                the rest of the it being meta information.
                Fallback to an empty array.
            ###
            if not _.isArray(response.objects)
                return []
            return response.objects

        postFetch: (response) ->
            ###
                Trigger `no_data` post-fetch, in order to make sure the
                received collection is up to that (empty in this case).
            ###
            if not _.isArray(objects = response.objects)
                @trigger_no_data()
            else if objects.length == 0
                @trigger_no_data()

        get_first_items: ->
            ###
                Get the first items from the collection, useful
                in stream poll situations
            ###
            data_length     = @length
            buffer_length   = @buffer.length
            #   Empty data means that we should be requesting with no 'since',
            #   or otherwise we would be requesting mentions newer than "now"
            if (data_length == 0 && buffer_length == 0)
                return null

            if (buffer_length > 0)
                #   Items are fetched into the buffer in reverse order
                #   due to incremental fetching.
                return @buffer.last()
            else
                return @first()

        filter_by: (filters = {}) ->
            ###
                Returns the collection filtered by multiple exclusive filters
                Allows calls like these:

                collection.filter_by(
                    'author/url': 'http://twitter.com/username'
                    'getOriginalURLDomain': 'blogname.wordpress.com'
                    )
            ###
            return @filter( (model) ->
                for key, value of filters
                    model_attr_value = model.getNested(key)
                    # Exclude the model that doesn't match one of the filters
                    # The filters are exclusive
                    return false unless model_attr_value is value

                # The model matches all filters
                return true
            )

        multi_get: (args...) =>
            ###
                Calls get() with each parameter given as argument and
                aggregates the results.
            ###
            return (@get(arg) for arg in args)

        _onModelEvent: (event, model, collection, options) ->
            ###
                _onModelEvent is an internal Backbone function that it uses
                to bubble up events from individual models all the way to
                collections.

                We want to prevent Backbone from bubbling up our custom
                invalidate model, because when a model is invalidated,
                that doesn't mean anything about the whole collection
                (the collection still owns those items, only one of them
                has to be re-rendered correctly).
            ###

            # Prevent 'invalidate' from bubbling up
            if event == 'invalidate'
                return

            # Bubble up all other events as Backbone wishes
            super(event, model, collection, options)

        new_items_in_buffer: =>
            ###
                For streampoll-enabled Backbone Collections, count how many
                new items there are actually in their associated buffer.

                We need to do this because of a datasource / endpoint legacy
                bug that sometimes delivers duplicate mentions.
            ###
            new_items = 0
            for model in @buffer.models
                if not @get(model.id)
                    new_items = new_items + 1
            return new_items

    return BaseCollection
