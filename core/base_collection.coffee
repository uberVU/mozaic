define [], () ->
    class BaseCollection extends Backbone.Collection
        collection_type: 'relational'

        parse: (response) ->
            if response.objects
                resp = response.objects
                # If the response has length 0, then a no_data event should
                # be trigger, otherwise the call will fail silently
                if resp.length == 0
                    @trigger('no_data', @)
                return resp
            return {}

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

    return BaseCollection