define [], () ->
    class BaseModel extends Backbone.Model

        unsyncable_attributes: []

        validate: (attributes, options) ->
            ###
                Check to see if the model is already in collection and
                log this as a warning message
            ###

            # Don't prevent adding an existing item to a collection
            # (because it will throw an error). However, log a message
            # for the developers to know there's something wrong.
            #
            # When this message is logged, it means that we're probably
            # requesting the same data more than once and wasting HTTP requests.
            if options and options.collection and options.collection.get(attributes.id)
                logger.warn("Trying to add an existing model #{attributes.id} " +
                         "(#{JSON.stringify(attributes)}}) to a collection")

            return false

        url: ->
            ###
                Returns the url of the model or the url of the collection
                if the model has not been saved yet.
                http://documentcloud.github.com/backbone/#Model-url
                A model that has not yet been saved will not have a collection
                (this is our usage pattern right now). Fallback to the
                urlRoot of the model in that case
            ###
            if @collection?
                if @id?
                    return Utils.model_url(@collection.url, @id)
                else
                    return @collection.url
            else if @urlRoot?
                if @id?
                    return Utils.model_url(@urlRoot, @id)
                else
                    return @urlRoot
            throw('Set a collection or the urlRoot property on the model')

        getSchema: (schema_name = 'default') ->
            throw('Implement this in your model for form support')

        save: (key, value, options) ->
            ###
                Overwrite the save method to provide a way to
                black list unwanted local attributes.
                For example we set a folders attribute on a stream
                and that doesn't map to any server attributes, so
                we shouldn't send it.

                Iterate over the unsyncable attributes and unset their
                values before sending the request to the server and
                then set them back once the operation is done
            ###
            unsynced_values = []
            for attribute in @unsyncable_attributes
                # Keep the current value of the attribute
                # to set it again after the save
                unsynced_values.push(@get(attribute))
                @unset(attribute, { silent: true })
            super(key, value, options)
            for attribute, i in @unsyncable_attributes
                # Set the old value back
                @set(attribute, unsynced_values[i], { silent: true })

    return BaseModel